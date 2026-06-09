import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/app_state_manager.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/ai_webhook_service.dart';
import '../../core/services/open_router_service.dart';

class HubChatAiScreen extends StatefulWidget {
  const HubChatAiScreen({super.key});

  @override
  State<HubChatAiScreen> createState() => _HubChatAiScreenState();
}

class _HubChatAiScreenState extends State<HubChatAiScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OpenRouterService _openRouterService = OpenRouterService();
  final AiWebhookService _aiWebhookService = AiWebhookService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isTyping = false;
  Map<String, dynamic>? _childContext;
  List<dynamic> _children = [];
  String? _selectedChildId;

  // 3-dot animations
  List<AnimationController> _dotControllers = [];
  List<Animation<double>> _dotAnimations = [];

  final List<Map<String, String>> _quickSuggestions = [
    {'icon': '🔍', 'text': "Analyze my child's activity"},
    {'icon': '🛡️', 'text': 'Digital safety advice'},
    {'icon': '📍', 'text': 'Explain the last alert'},
    {'icon': '⏰', 'text': 'Usage schedules'},
    {'icon': '🌐', 'text': 'Which sites to block?'},
    {'icon': '🚨', 'text': 'My child is in danger!'},
  ];

  @override
  void initState() {
    super.initState();
    _initDotAnimations();
    _loadChildren();
    _sendWelcomeMessage();
  }

  void _initDotAnimations() {
    _dotControllers = List.generate(
        3,
        (i) => AnimationController(
              vsync: this,
              duration: const Duration(milliseconds: 520),
            ));
    _dotAnimations = _dotControllers
        .map((ctrl) => Tween<double>(begin: 0, end: -8).animate(
              CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
            ))
        .toList();
  }

  void _startDotAnimations() {
    for (int i = 0; i < _dotControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _dotControllers[i].repeat(reverse: true);
      });
    }
  }

  void _stopDotAnimations() {
    for (final ctrl in _dotControllers) {
      ctrl.stop();
      ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    for (final ctrl in _dotControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChildren() async {
    try {
      final children = await _firestoreService.getMyChildren();
      if (mounted) {
        setState(() {
          _children = children;
          if (_children.isNotEmpty) {
            final extra =
                GoRouterState.of(context).extra as Map<String, dynamic>?;
            if (extra != null && extra['child'] != null) {
              final child = extra['child'];
              _selectChild(child);
              if (extra['mode'] == 'setup') {
                _sendSetupMessage(child);
              }
            } else {
              _selectChild(_children[0]);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading children: $e');
    }
  }

  void _selectChild(dynamic child) {
    setState(() {
      _selectedChildId = child['id'] ?? child['childId'];
      _childContext = {
        'id': _selectedChildId,
        'name': child['displayName'] ?? 'Child',
        'age': child['age'] ?? 10,
        'deviceStatus': child['deviceStatus'] ?? 'Unknown',
        'battery': child['batteryLevel'] != null
            ? '${(child['batteryLevel'] as num).toInt()}%'
            : 'Unknown',
      };
    });
  }

  void _sendSetupMessage(dynamic child) {
    final name = child['displayName'] ?? 'the child';
    _messageController.text =
        "I just created a profile for $name. Can you help me configure basic parental rules suitable for their age?";
  }

  void _showChildPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF13132A) : Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a child',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            ..._children.map((child) {
              final id = child['id'] ?? child['childId'];
              final isSelected = id == _selectedChildId;
              return ListTile(
                onTap: () {
                  _selectChild(child);
                  Navigator.pop(ctx);
                },
                leading: CircleAvatar(
                  backgroundColor:
                      isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  child: Text(child['displayName']?[0] ?? 'C',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                ),
                title: Text(child['displayName'] ?? 'Child',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
              );
            }),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _sendWelcomeMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stateManager = Provider.of<AppStateManager>(context, listen: false);
      if (stateManager.chatHistory.isEmpty) {
        stateManager.addChatMessage(ChatMessage(
          id: DateTime.now().toIso8601String(),
          text:
              '👋 Hi! I am **Guardian AI**, your parental security assistant.\n\n'
              '## What I can do for you\n\n'
              '• 🔍 Analyze your children\'s activity\n'
              '• 🛡️ Give you tailored security advice\n'
              '• 📊 Explain alerts received\n'
              '• ⚙️ Help you configure parental rules\n\n'
              'Feel free to ask me anything, I\'m here to help! 😊',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      }
    });
  }

  Future<void> _sendMessage(AppStateManager stateManager,
      {String? quickMessage}) async {
    final text = quickMessage ?? _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;

    stateManager.addChatMessage(ChatMessage(
      id: DateTime.now().toIso8601String(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _messageController.clear();
    setState(() => _isTyping = true);
    _startDotAnimations();
    _scrollToBottom();

    try {
      // Fetch fresh data from Firestore to avoid "fictive" data
      Map<String, dynamic>? enrichedContext = _childContext != null ? Map<String, dynamic>.from(_childContext!) : null;
      if (enrichedContext != null) {
        final childId = enrichedContext['id'];
        final stats = await FirestoreService().getUsageStats(childId);
        final rules = await FirestoreService().getRules(childId);
        final alerts = await FirestoreService().getRecentAlerts(childId);

        enrichedContext['usage'] = stats;
        enrichedContext['rules'] = rules;
        enrichedContext['recentAlerts'] = alerts;
      }
      // Using local Webhook for testing (n8n)
      final parentId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_parent';
      final childId = _selectedChildId ?? 'unknown_child';
      
      final response = await _aiWebhookService.sendMessage(
        text,
        parentId: parentId,
        childId: childId,
        childContext: enrichedContext,
      );
      if (mounted) {
        stateManager.addChatMessage(ChatMessage(
          id: DateTime.now().toIso8601String(),
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      if (mounted) {
        stateManager.addChatMessage(ChatMessage(
          id: DateTime.now().toIso8601String(),
          text: '❌ Connection error. Check your internet and try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _stopDotAnimations();
        _scrollToBottom();
      }
    }
  }

  Future<void> _analyzeChildActivity(AppStateManager stateManager) async {
    if (_childContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No child found.')),
      );
      return;
    }
    await _sendMessage(stateManager,
        quickMessage: '🔍 Analyze ${_childContext!['name']}\'s activity');
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ✅ BOTTOM SHEET — Session list (title only) + detail on click
  void _showHistorySheet(AppStateManager stateManager) {
    // Group messages into "sessions": each session = one conversation
    // Currently we have one session, but the structure is ready
    final messages = stateManager.chatHistory;

    // Build session list from messages
    // Split into sessions: a new session starts after 30 mins of silence
    final List<_ChatSession> sessions = _buildSessions(messages);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => _HistoryPanel(
          sessions: sessions,
          stateManager: stateManager,
          onClear: () {
            Navigator.pop(ctx);
            _openRouterService.clearHistory();
            stateManager.clearChatHistory();
            _sendWelcomeMessage();
          },
          onSessionTap: (session) {
            Navigator.pop(ctx);
            _showSessionDetail(session);
          },
        ),
      ),
    );
  }

  // Split messages into sessions (30min gap = new session)
  List<_ChatSession> _buildSessions(List<ChatMessage> messages) {
    if (messages.isEmpty) return [];

    final sessions = <_ChatSession>[];
    List<ChatMessage> current = [];

    for (int i = 0; i < messages.length; i++) {
      if (current.isEmpty) {
        current.add(messages[i]);
      } else {
        final gap = messages[i].timestamp.difference(current.last.timestamp);
        if (gap.inMinutes > 30) {
          sessions.add(_ChatSession(messages: current));
          current = [messages[i]];
        } else {
          current.add(messages[i]);
        }
      }
    }
    if (current.isNotEmpty) sessions.add(_ChatSession(messages: current));
    return sessions.reversed.toList(); // Most recent first
  }

  // Opens session details in another bottom sheet
  void _showSessionDetail(_ChatSession session) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF13132A) : Theme.of(context).colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07)),
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        SizedBox(height: 14),
                        Row(children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showHistorySheet(Provider.of<AppStateManager>(
                                  context,
                                  listen: false));
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.arrow_back_ios_new,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 15),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(session.title,
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  Text(session.subtitle,
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11)),
                                ]),
                          ),
                        ]),
                        SizedBox(height: 12),
                        Divider(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
                            height: 1),
                      ]),
                    ),
                    // Session messages
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: session.messages.length,
                        itemBuilder: (_, i) {
                          final msg = session.messages[i];
                          final isUser = msg.isUser;
                          final time =
                              '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
                          return Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: isUser
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isUser) ...[
                                  _aiAvatar(),
                                  SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: LayoutBuilder(
                                    builder: (ctx2, constraints) => Container(
                                      constraints: BoxConstraints(
                                          maxWidth:
                                              constraints.maxWidth * 0.82),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: isUser
                                            ? LinearGradient(colors: [
                                                AppColors.primary,
                                                AppColors.primary
                                                    .withValues(alpha: 0.85)
                                              ])
                                            : null,
                                        color: isUser ? null : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E35) : const Color(0xFFF1F5F9)),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft:
                                              Radius.circular(isUser ? 16 : 4),
                                          bottomRight:
                                              Radius.circular(isUser ? 4 : 16),
                                        ),
                                        border: isUser
                                            ? null
                                            : Border.all(
                                                color: Theme.of(context).colorScheme.onSurface
                                                    .withValues(alpha: 0.07)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          isUser
                                              ? Text(msg.text,
                                                  style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontSize: 14,
                                                      height: 1.4))
                                              : _buildMarkdownContent(msg.text,
                                                  compact: true),
                                          SizedBox(height: 3),
                                          Text(time,
                                              style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                                                  fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (isUser) SizedBox(width: 8),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ));
  }

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final stateManager = Provider.of<AppStateManager>(context);
    final messages = stateManager.chatHistory;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (Theme.of(context).brightness == Brightness.dark) const LiquidBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(stateManager),
                _buildChildSwitcher(),
                if (_childContext != null) _buildChildContextBanner(),
                Expanded(
                  child: messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                          itemCount: messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isTyping && index == messages.length) {
                              return _buildTypingIndicator();
                            }
                            return _buildMessageBubble(messages[index]);
                          },
                        ),
                ),
                if (messages.length <= 2) _buildQuickSuggestions(stateManager),
                _buildInputArea(stateManager),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR CUSTOM
  // ============================================================

  Widget _buildAppBar(AppStateManager stateManager) {
    return Container(
      padding: EdgeInsets.fromLTRB(6, 8, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
        border: Border(
            bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 18),
            onPressed: () => context.pop(),
          ),
          // Avatar glow
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accentTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Icon(Icons.shield, color: Theme.of(context).colorScheme.onSurface, size: 18),
          ),
          SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _children.length > 1 ? _showChildPicker : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Guardian AI',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3)),
                      if (_children.length > 1) ...[
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 20),
                      ],
                    ],
                  ),
                  Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isTyping
                            ? Colors.orangeAccent
                            : Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isTyping ? Colors.orange : Colors.green)
                                .withValues(alpha: 0.7),
                            blurRadius: 5,
                          )
                        ],
                      ),
                    ),
                    SizedBox(width: 5),
                        Text(
                          _isTyping ? 'AI is writing...' : 'Parental Assistant',
                          style: TextStyle(
                            color: _isTyping
                                ? Colors.orangeAccent.withValues(alpha: 0.8)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                  ]),
                ],
              ),
            ),
          ),

          // ✅ Bouton 3 traits pour ouvrir l'historique
          GestureDetector(
            onTap: () => _showHistorySheet(stateManager),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.09)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    3,
                    (i) => Container(
                          width: 16,
                          height: 2,
                          margin: EdgeInsets.only(bottom: i < 2 ? 3.5 : 0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )),
              ),
            ),
          ),
          SizedBox(width: 4),
          if (_childContext != null)
            IconButton(
              icon: Icon(Icons.bar_chart_rounded,
                  color: AppColors.accentTeal, size: 20),
              onPressed: () => _analyzeChildActivity(stateManager),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // WIDGETS
  // ============================================================

  Widget _buildChildSwitcher() {
    if (_children.isEmpty) return SizedBox.shrink();
    return Container(
      height: 90,
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
        border: Border(
            bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: _children.length,
        itemBuilder: (context, index) {
          final child = _children[index];
          final id = child['id'] ?? child['childId'];
          final isSelected = id == _selectedChildId;
          return GestureDetector(
            onTap: () => _selectChild(child),
            child: Container(
              margin: EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: isSelected
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      child: Text(
                        child['displayName']?[0] ?? 'C',
                        style: TextStyle(
                          color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    child['displayName'] ?? 'Child',
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChildContextBanner() {
    return Container(
      margin: EdgeInsets.fromLTRB(14, 0, 14, 0),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
          child: Text(
            (_childContext!['name'] as String)[0].toUpperCase(),
            style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Context: ${_childContext!['name']}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          Text(
              '${_childContext!['age']} years old · ${_childContext!['deviceStatus']} · 🔋 ${_childContext!['battery']}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 10)),
        ])),
        Icon(Icons.info_outline_rounded,
            color: AppColors.primary.withValues(alpha: 0.5), size: 15),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accentTeal]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              )
            ],
          ),
          child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onSurface, size: 32),
        ),
        SizedBox(height: 16),
        Text('Ask me your first question!',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 14)),
      ]),
    );
  }

  // ✅ CHATGPT STYLE TYPING INDICATOR
  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16, left: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E35),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Guardian AI is writing',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70),
                      fontSize: 14,
                      fontStyle: FontStyle.italic)),
              SizedBox(width: 6),
              AnimatedBuilder(
                animation: _dotAnimations[0],
                builder: (_, __) => Opacity(
                  opacity: (_dotAnimations[0].value / -8).abs().clamp(0.0, 1.0),
                  child: Container(
                    width: 6,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }


  Widget _aiAvatar() => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [AppColors.primary, AppColors.accentTeal]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)
          ],
        ),
        child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onSurface, size: 15),
      );

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final time =
        '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return TweenAnimationBuilder<double>(
      key: ValueKey(msg.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuad,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 15 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.82),
                    padding: isUser
                        ? EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12)
                        : EdgeInsets.fromLTRB(16, 13, 16, 12),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.85)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isUser ? null : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E35) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07)),
                      boxShadow: [
                        BoxShadow(
                          color: isUser
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: isUser
                        ? Text(msg.text,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 15,
                                height: 1.45))
                        : _buildMarkdownContent(msg.text),
                  ),
                  SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(time,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), fontSize: 10)),
                    if (isUser) ...[
                      SizedBox(width: 4),
                      Icon(Icons.done_all_rounded,
                          size: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                    ],
                  ]),
                ],
              ),
            ),
            if (isUser) SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ROBUST MARKDOWN PARSER
  // ============================================================

  Widget _buildMarkdownContent(String text, {bool compact = false}) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    final double fs = compact ? 13.5 : 14.5;

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        widgets.add(SizedBox(height: compact ? 4 : 5));
        continue;
      }

      if (RegExp(r'^-{3,}$').hasMatch(trimmed)) {
        widgets.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 7),
          child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
        ));
        continue;
      }

      final headingMatch = RegExp(r'^(#{1,3})\s+(.+)').firstMatch(trimmed);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final title = _stripInline(headingMatch.group(2)!);
        widgets.add(Padding(
          padding: EdgeInsets.only(top: compact ? 6 : 9, bottom: 3),
          child: Text(title,
              style: TextStyle(
                color: level == 1 ? Theme.of(context).colorScheme.onSurface : AppColors.accentTeal,
                fontSize: level == 1
                    ? fs + 2
                    : level == 2
                        ? fs + 1
                        : fs,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              )),
        ));
        continue;
      }

      final bulletMatch = RegExp(r'^[•\*\-]\s+(.+)').firstMatch(trimmed);
      if (bulletMatch != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 3, left: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 5,
              height: 5,
              margin: EdgeInsets.only(top: 8, right: 9),
              decoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
            ),
            Expanded(child: _inlineText(bulletMatch.group(1)!, fs)),
          ]),
        ));
        continue;
      }

      final numMatch = RegExp(r'^(\d+)[\.]\s+(.+)').firstMatch(trimmed);
      if (numMatch != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 4, left: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 20,
              height: 20,
              margin: EdgeInsets.only(top: 2, right: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                  child: Text(numMatch.group(1)!,
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700))),
            ),
            Expanded(child: _inlineText(numMatch.group(2)!, fs)),
          ]),
        ));
        continue;
      }

      widgets.add(Padding(
        padding: EdgeInsets.only(bottom: 1),
        child: _inlineText(trimmed, fs),
      ));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  String _stripInline(String t) => t
      .replaceAllMapped(RegExp(r'\*{1,3}(.*?)\*{1,3}'), (m) => m.group(1) ?? '')
      .replaceAllMapped(RegExp(r'`(.*?)`'), (m) => m.group(1) ?? '');

  Widget _inlineText(String text, double fontSize) {
    final spans = <InlineSpan>[];
    final pattern =
        RegExp(r'\*{3}(.+?)\*{3}|\*{2}(.+?)\*{2}|\*(.+?)\*|`(.+?)`');
    int cursor = 0;
    final base = TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
        fontSize: fontSize,
        height: 1.5);

    for (final m in pattern.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start), style: base));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(1),
            style: base.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(2),
            style: base.copyWith(
                color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(3),
            style: base.copyWith(fontStyle: FontStyle.italic)));
      } else if (m.group(4) != null) {
        spans.add(WidgetSpan(
            child: Container(
          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          margin: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Text(m.group(4)!,
              style: TextStyle(
                  color: AppColors.accentTeal,
                  fontSize: fontSize - 1,
                  fontFamily: 'monospace')),
        )));
      }
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: base));
    }
    if (spans.isEmpty) return Text(text, style: base);
    return RichText(text: TextSpan(children: spans));
  }

  // ============================================================
  // SUGGESTIONS + INPUT
  // ============================================================

  Widget _buildQuickSuggestions(AppStateManager stateManager) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        itemCount: _quickSuggestions.length,
        itemBuilder: (context, index) {
          final s = _quickSuggestions[index];
          return GestureDetector(
            onTap: () => _sendMessage(stateManager, quickMessage: s['text']),
            child: Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(s['icon']!, style: TextStyle(fontSize: 13)),
                SizedBox(width: 5),
                Text(s['text']!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(AppStateManager stateManager) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.98),
        border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05))),
      ),
      child: SafeArea(
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E35),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _messageController,
                readOnly: _isTyping,
                style: TextStyle(
                    color: _isTyping ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54) : Theme.of(context).colorScheme.onSurface,
                    fontSize: 15),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(stateManager),
                decoration: InputDecoration(
                  hintText: _isTyping
                      ? 'Generation in progress...'
                      : 'Send a message to Guardian AI...',
                  hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _isTyping ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1) : AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: _isTyping
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: IconButton(
              onPressed: _isTyping ? null : () => _sendMessage(stateManager),
              icon: Icon(
                _isTyping ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                color: _isTyping ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54) : Theme.of(context).colorScheme.onSurface,
                size: 22,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================
// SESSION MODEL
// ============================================================

class _ChatSession {
  final List<ChatMessage> messages;

  _ChatSession({required this.messages});

  // Premier message user comme titre
  String get title {
    final firstUser = messages.firstWhere(
      (m) => m.isUser,
      orElse: () => messages.first,
    );
    final t = firstUser.text.trim();
    if (t.length <= 48) return t;
    return '${t.substring(0, 45)}...';
  }

  String get subtitle {
    final d = messages.first.timestamp;
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inDays == 0) {
      return "Today at ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
    }
    if (diff.inDays == 1) {
      return "Yesterday at ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
    }
    return "${d.day}/${d.month}/${d.year} — ${messages.length} messages";
  }

  int get messageCount => messages.length;
  bool get hasAiResponse => messages.any((m) => !m.isUser);
}

// ============================================================
// HISTORY PANEL — session list
// ============================================================

class _HistoryPanel extends StatelessWidget {
  final List<_ChatSession> sessions;
  final AppStateManager stateManager;
  final VoidCallback onClear;
  final void Function(_ChatSession) onSessionTap;

  const _HistoryPanel({
    required this.sessions,
    required this.stateManager,
    required this.onClear,
    required this.onSessionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF13132A) : Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07)),
      ),
      child: Column(children: [
        // ── Handle + Header ──
        Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(children: [
            // Handle (3 lines)
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            SizedBox(height: 16),
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.accentTeal]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.history_rounded,
                    color: Theme.of(context).colorScheme.onSurface, size: 17),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('History',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ),
              // Bouton effacer
              if (sessions.isNotEmpty)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 14),
                      SizedBox(width: 4),
                      Text('Clear all',
                          style:
                              TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ]),
                  ),
                ),
            ]),
            SizedBox(height: 14),
            Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07), height: 1),
          ]),
        ),

        // ── Liste des sessions ──
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 40,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
                        SizedBox(height: 12),
                        Text('No conversations yet.',
                            style:
                                TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 14)),
                      ]),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => Divider(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                  itemBuilder: (_, i) => _SessionTile(
                    session: sessions[i],
                    onTap: () => onSessionTap(sessions[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ── Session Tile ──
class _SessionTile extends StatelessWidget {
  final _ChatSession session;
  final VoidCallback onTap;

  const _SessionTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(children: [
          // Icône bulle
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.chat_rounded, color: AppColors.primary, size: 20),
          ),
          SizedBox(width: 13),
          // Titre + sous-titre
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 3),
              Text(
                session.subtitle,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 12),
              ),
            ]),
          ),
          SizedBox(width: 8),
          // Badge nombre de messages + flèche
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${session.messageCount} msg',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 6),
            Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), size: 18),
          ]),
        ]),
      ),
    );
  }
}
