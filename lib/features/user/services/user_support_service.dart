import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_options.dart';
import '../../../core/config/app_config.dart';
import '../models/user_support_constraints.dart';
import '../models/user_support_model.dart';

class UserSupportService {
  UserSupportService(this._apiClient);

  final ApiClient _apiClient;

  static final Options _readOptions = normalReadOptions();

  static final Options _multipartOptions = uploadOptions().copyWith(
    contentType: Headers.multipartFormDataContentType,
  );

  Future<List<UserSupportTicketListItem>> fetchTickets({
    UserSupportTicketStatus? status,
    String? search,
    int? page,
    int? limit,
    String? refreshKey,
  }) async {
    if (AppConfig.demoMode) {
      return _demoTickets(
        status: status,
        search: search,
        page: page,
        limit: limit,
      );
    }

    final response = await _apiClient.get<List<UserSupportTicketListItem>>(
      ApiEndpoints.user.tickets,
      queryParameters: _query(<String, dynamic>{
        'status': status?.apiValue,
        'search': search,
        'page': page,
        'limit': limit,
        'rk': refreshKey,
      }),
      options: _readOptions,
      parser: UserSupportTicketListItem.listFromJson,
    );

    final tickets = response.data.toList(growable: true);
    tickets.sort(UserSupportTicketListItem.compareInboxOrder);
    return tickets;
  }

  Future<UserSupportTicketDetail> fetchTicketById(String ticketId) async {
    final id = _requireId(ticketId, 'ticketId');

    if (AppConfig.demoMode) {
      final ticket = _demoTicketDetails().firstWhere(
        (item) => item.id == id,
        orElse: () => throw ArgumentError(
          'Demo ticket "$id" was not found.',
        ),
      );
      return ticket;
    }

    final response = await _apiClient.get<UserSupportTicketDetail>(
      ApiEndpoints.user.ticketById(id),
      options: _readOptions,
      parser: UserSupportTicketDetail.fromJson,
    );
    return response.data;
  }

  Future<UserSupportTicketDetail> createTicket({
    required String title,
    required String message,
    UserSupportTicketCategory category = UserSupportTicketCategory.other,
    UserSupportTicketPriority priority = UserSupportTicketPriority.medium,
    List<PlatformFile> attachments = const <PlatformFile>[],
  }) async {
    final request = UserCreateSupportTicketRequest(
      title: _normalizeTitle(title),
      message: _normalizeMessage(message),
      category: category,
      priority: priority,
      attachments: attachments,
    );

    _validateAttachments(request.attachments);

    if (AppConfig.demoMode) {
      return _createDemoTicket(
        title: request.title,
        message: request.message,
        category: request.category,
        priority: request.priority,
      );
    }

    final formData = await _buildTicketFormData(
      fields: request.toJson(),
      attachments: request.attachments,
    );

    final response = await _apiClient.post<dynamic>(
      ApiEndpoints.user.tickets,
      data: formData,
      options: _multipartOptions,
      parser: (json) => json,
    );

    final createdTicket = UserSupportTicketDetail.fromJson(response.data);
    if (createdTicket.id.trim().isEmpty) {
      return createdTicket;
    }

    try {
      return await fetchTicketById(createdTicket.id);
    } catch (_) {
      return createdTicket;
    }
  }

  Future<UserSupportTicketDetail> replyToTicket({
    required String ticketId,
    required String message,
    List<PlatformFile> attachments = const <PlatformFile>[],
  }) async {
    final id = _requireId(ticketId, 'ticketId');
    final request = UserReplySupportTicketRequest(
      message: _normalizeMessage(message),
      attachments: attachments,
    );

    _validateAttachments(request.attachments);

    if (AppConfig.demoMode) {
      return _replyToDemoTicket(
        ticketId: id,
        message: request.message,
      );
    }

    final formData = await _buildTicketFormData(
      fields: request.toJson(),
      attachments: request.attachments,
    );

    await _apiClient.post<dynamic>(
      ApiEndpoints.user.ticketById(id),
      data: formData,
      options: _multipartOptions,
      parser: (json) => json,
    );

    return fetchTicketById(id);
  }

  Future<FormData> _buildTicketFormData({
    required Map<String, dynamic> fields,
    required List<PlatformFile> attachments,
  }) async {
    final formData = FormData();
    for (final entry in fields.entries) {
      final value = entry.value?.toString().trim();
      if (value == null || value.isEmpty) {
        continue;
      }
      formData.fields.add(MapEntry(entry.key, value));
    }

    for (final attachment in attachments) {
      formData.files.add(
        MapEntry('attachments', await _toMultipartFile(attachment)),
      );
    }

    return formData;
  }

  Future<MultipartFile> _toMultipartFile(PlatformFile file) async {
    final fileName = file.name.trim().isEmpty ? 'attachment' : file.name.trim();
    final contentType =
        _contentTypeForExtension(userSupportExtensionFromFileName(fileName));

    if (file.bytes != null) {
      return MultipartFile.fromBytes(
        file.bytes!,
        filename: fileName,
        contentType: contentType,
      );
    }

    final path = file.path?.trim();
    if (path != null && path.isNotEmpty) {
      return MultipartFile.fromFile(
        path,
        filename: fileName,
        contentType: contentType,
      );
    }

    throw ArgumentError('Unable to read attachment "$fileName".');
  }

  String _normalizeTitle(String title) {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Title is required.');
    }
    if (normalized.length > userSupportMaxTitleLength) {
      throw ArgumentError(
        'Title must be $userSupportMaxTitleLength characters or less.',
      );
    }
    if (!userSupportContainsLetterOrNumber(normalized)) {
      throw ArgumentError('Title must contain at least one letter or number.');
    }
    return normalized;
  }

  String _normalizeMessage(String message) {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Message is required.');
    }
    if (normalized.length > userSupportMaxMessageLength) {
      throw ArgumentError(
        'Message must be $userSupportMaxMessageLength characters or less.',
      );
    }
    if (!userSupportContainsLetterOrNumber(normalized)) {
      throw ArgumentError(
          'Message must contain at least one letter or number.');
    }
    return normalized;
  }

  void _validateAttachments(List<PlatformFile> attachments) {
    if (attachments.length > userSupportMaxAttachmentCount) {
      throw ArgumentError(
        'You can upload up to $userSupportMaxAttachmentCount files.',
      );
    }

    for (final attachment in attachments) {
      final fileName = attachment.name.trim().isEmpty
          ? 'attachment'
          : attachment.name.trim();
      final extension = userSupportExtensionFromFileName(fileName);
      if (userSupportBlockedAttachmentExtensions.contains(extension)) {
        throw ArgumentError(
          '"$fileName" is blocked. Please remove executable or script-like files.',
        );
      }
      if (!userSupportAllowedAttachmentExtensions.contains(extension)) {
        throw ArgumentError(
          '"$fileName" is not supported. Allowed files: ${userSupportAllowedAttachmentExtensions.join(', ')}.',
        );
      }
      if (attachment.size > userSupportMaxAttachmentBytes) {
        throw ArgumentError('"$fileName" exceeds the 5MB size limit.');
      }
    }
  }

  static final List<UserSupportTicketDetail> _demoTicketsStore =
      _buildInitialDemoTickets();

  List<UserSupportTicketListItem> _demoTickets({
    UserSupportTicketStatus? status,
    String? search,
    int? page,
    int? limit,
  }) {
    final normalizedSearch = search?.trim().toLowerCase();

    final filtered = _demoTicketsStore
        .where((ticket) {
          if (status != null && ticket.status != status) {
            return false;
          }

          if (normalizedSearch == null || normalizedSearch.isEmpty) {
            return true;
          }

          return ticket.toListItem().searchContent.contains(normalizedSearch);
        })
        .map((ticket) => ticket.toListItem())
        .toList(growable: true);

    filtered.sort(UserSupportTicketListItem.compareInboxOrder);

    final normalizedPage = page == null || page < 1 ? 1 : page;
    final normalizedLimit = limit == null || limit < 1 ? 50 : limit;
    final start = (normalizedPage - 1) * normalizedLimit;

    if (start >= filtered.length) {
      return <UserSupportTicketListItem>[];
    }

    return filtered
        .skip(start)
        .take(normalizedLimit)
        .toList(growable: false);
  }

  List<UserSupportTicketDetail> _demoTicketDetails() {
    return List<UserSupportTicketDetail>.from(_demoTicketsStore);
  }

  UserSupportTicketDetail _createDemoTicket({
    required String title,
    required String message,
    required UserSupportTicketCategory category,
    required UserSupportTicketPriority priority,
  }) {
    final now = DateTime.now();
    final sequence = _demoTicketsStore.length + 1;
    final id = 'demo-support-${sequence.toString().padLeft(3, '0')}';
    final ticketNo = 'SMARTAVL-$sequence';

    final user = _demoCurrentUser();
    final support = _demoSupportUser();

    final ticketMessage = UserSupportTicketMessage(
      id: '$id-message-001',
      message: message,
      senderId: user.id,
      createdAt: now,
      sender: user,
      attachments: const <UserSupportTicketAttachment>[],
    );

    final ticket = UserSupportTicketDetail(
      id: id,
      ticketNo: ticketNo,
      title: title,
      status: UserSupportTicketStatus.open,
      category: category,
      priority: priority,
      messageCount: 1,
      lastMessageAt: now,
      createdAt: now,
      updatedAt: now,
      closedAt: null,
      fromUser: user,
      toUser: support,
      messages: <UserSupportTicketMessage>[ticketMessage],
    );

    _demoTicketsStore.insert(0, ticket);
    return ticket;
  }

  UserSupportTicketDetail _replyToDemoTicket({
    required String ticketId,
    required String message,
  }) {
    final index = _demoTicketsStore.indexWhere(
      (ticket) => ticket.id == ticketId,
    );

    if (index < 0) {
      throw ArgumentError('Demo ticket "$ticketId" was not found.');
    }

    final existing = _demoTicketsStore[index];

    if (existing.isClosed) {
      throw StateError('This support ticket is closed.');
    }

    final now = DateTime.now();
    final user = _demoCurrentUser();

    final reply = UserSupportTicketMessage(
      id: '${existing.id}-message-${existing.messages.length + 1}',
      message: message,
      senderId: user.id,
      createdAt: now,
      sender: user,
      attachments: const <UserSupportTicketAttachment>[],
    );

    final updated = UserSupportTicketDetail(
      id: existing.id,
      ticketNo: existing.ticketNo,
      title: existing.title,
      status: UserSupportTicketStatus.inProgress,
      category: existing.category,
      priority: existing.priority,
      messageCount: existing.messages.length + 1,
      lastMessageAt: now,
      createdAt: existing.createdAt,
      updatedAt: now,
      closedAt: existing.closedAt,
      fromUser: existing.fromUser,
      toUser: existing.toUser,
      messages: <UserSupportTicketMessage>[
        ...existing.messages,
        reply,
      ],
    );

    _demoTicketsStore[index] = updated;
    return updated;
  }

  static List<UserSupportTicketDetail> _buildInitialDemoTickets() {
    final now = DateTime.now();
    final user = _demoCurrentUser();
    final support = _demoSupportUser();

    UserSupportTicketDetail buildTicket({
      required String id,
      required String ticketNo,
      required String title,
      required UserSupportTicketStatus status,
      required UserSupportTicketCategory category,
      required UserSupportTicketPriority priority,
      required String message,
      required int daysAgo,
      String? supportReply,
    }) {
      final createdAt = now.subtract(Duration(days: daysAgo));

      final messages = <UserSupportTicketMessage>[
        UserSupportTicketMessage(
          id: '$id-message-001',
          message: message,
          senderId: user.id,
          createdAt: createdAt,
          sender: user,
          attachments: const <UserSupportTicketAttachment>[],
        ),
      ];

      if (supportReply != null) {
        messages.add(
          UserSupportTicketMessage(
            id: '$id-message-002',
            message: supportReply,
            senderId: support.id,
            createdAt: createdAt.add(const Duration(hours: 3)),
            sender: support,
            attachments: const <UserSupportTicketAttachment>[],
          ),
        );
      }

      final lastMessageAt = messages.last.createdAt;

      return UserSupportTicketDetail(
        id: id,
        ticketNo: ticketNo,
        title: title,
        status: status,
        category: category,
        priority: priority,
        messageCount: messages.length,
        lastMessageAt: lastMessageAt,
        createdAt: createdAt,
        updatedAt: lastMessageAt,
        closedAt: status == UserSupportTicketStatus.closed
            ? lastMessageAt
            : null,
        fromUser: user,
        toUser: support,
        messages: messages,
      );
    }

    return <UserSupportTicketDetail>[
      buildTicket(
        id: 'demo-support-001',
        ticketNo: 'SMARTAVL-1001',
        title: 'Vehicle is not updating',
        status: UserSupportTicketStatus.inProgress,
        category: UserSupportTicketCategory.server,
        priority: UserSupportTicketPriority.high,
        message:
            'My vehicle tracking data has not updated for the last few minutes.',
        daysAgo: 1,
        supportReply:
            'Thanks for contacting Smart AVL Fleet Support. We are checking the tracking connection.',
      ),
      buildTicket(
        id: 'demo-support-002',
        ticketNo: 'SMARTAVL-1002',
        title: 'Map display question',
        status: UserSupportTicketStatus.open,
        category: UserSupportTicketCategory.maps,
        priority: UserSupportTicketPriority.medium,
        message:
            'How can I change the map view used for my fleet?',
        daysAgo: 3,
      ),
      buildTicket(
        id: 'demo-support-003',
        ticketNo: 'SMARTAVL-1003',
        title: 'Notification settings',
        status: UserSupportTicketStatus.closed,
        category: UserSupportTicketCategory.notifications,
        priority: UserSupportTicketPriority.low,
        message:
            'I wanted to understand how vehicle notification settings work.',
        daysAgo: 7,
        supportReply:
            'Notification preferences can be configured from the notification settings section.',
      ),
    ];
  }

  static UserSupportParticipant _demoCurrentUser() {
    return const UserSupportParticipant(
      id: '1',
      name: 'Demo User',
      email: 'demo@openvts.local',
      mobilePrefix: '+1',
      mobileNumber: '5559876543',
      role: 'user',
    );
  }

  static UserSupportParticipant _demoSupportUser() {
    return const UserSupportParticipant(
      id: 'demo-support-agent',
      name: 'Smart AVL Support',
      email: 'support@smartavl.net',
      mobilePrefix: '+966',
      mobileNumber: '5000000000',
      role: 'support',
    );
  }

  String _requireId(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('$fieldName is required.');
    }
    return normalized;
  }

  Map<String, dynamic>? _query(Map<String, dynamic> values) {
    final query = <String, dynamic>{};
    for (final entry in values.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      query[entry.key] = value;
    }
    return query.isEmpty ? null : query;
  }

  MediaType _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case 'txt':
        return MediaType('text', 'plain');
      case 'zip':
        return MediaType('application', 'zip');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}
