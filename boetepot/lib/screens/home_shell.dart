import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../services/boete_service.dart';
import '../services/notifications_service.dart';
import '../models.dart';
import '../ui.dart';

import 'groups_screen.dart';
import 'boetes_screen.dart';
import 'betalingen_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'templates_screen.dart';
import 'group_members_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  String? _selectedGroupId;
  String? _selectedGroupName;
  Map<String, String> _currentRoles = {};
  List<AppUser> _currentMembers = [];
  final _boeteService = BoeteService();
  final GlobalKey _fabKey = GlobalKey();

  void _selectGroup({
    required String uid,
    required String id,
    required String name,
    bool closePicker = false,
  }) {
    setState(() {
      _selectedGroupId = id;
      _selectedGroupName = name;
    });
    _startMembersWatch(id);
    unawaited(
      NotificationsService.syncForGroup(uid: uid, groupId: id).catchError((_) {
        // Best-effort; user may have notifications disabled at OS level.
      }),
    );
    if (closePicker) Navigator.pop(context);
  }

  Future<void> _showCreatePotSheet() async {
    final name = TextEditingController();
    final emails = TextEditingController();
    String? error;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppBottomSheet(
        childBuilder: (sheetContext, scrollController) {
          return StatefulBuilder(
            builder: (context, setState) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nieuwe BoetePot',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Naam'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emails,
                    decoration: const InputDecoration(labelText: 'Lid e-mails (komma gescheiden, optioneel)'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final n = name.text.trim();
                          if (n.isEmpty) {
                            setState(() => error = 'Naam is verplicht');
                            return;
                          }
                          final emailList = emails.text
                              .split(',')
                              .map((e) => e.trim().toLowerCase())
                              .where((e) => e.isNotEmpty)
                              .toList();
                          try {
                            final newId = await GroupService().createGroup(
                              name: n,
                              currentUid: FirebaseAuth.instance.currentUser!.uid,
                              memberEmails: emailList,
                            );
                            setState(() => error = null);
                            if (!mounted) return;
                            Navigator.pop(context);
                            _selectGroup(
                              uid: FirebaseAuth.instance.currentUser!.uid,
                              id: newId,
                              name: n,
                            );
                          } catch (e) {
                            setState(() => error = e.toString());
                          }
                        },
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openGroupPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: GroupsScreen(
            onSelect: (id, name) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              _selectGroup(uid: uid, id: id, name: name, closePicker: true);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showAddBoeteDialog() async {
    if (_selectedGroupId == null) return;
    final title = TextEditingController();
    final desc = TextEditingController();
    final amount = TextEditingController();
    String selectedUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppBottomSheet(
        childBuilder: (sheetContext, scrollController) {
          return StatefulBuilder(
            builder: (context, setState) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add Boete',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 10),
                  TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amount,
                    decoration: const InputDecoration(labelText: 'Amount (€)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUid,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Assign to'),
                    items: _currentMembers.map((u) {
                      final label = (u.displayName?.isNotEmpty == true) ? u.displayName! : u.email;
                      return DropdownMenuItem(value: u.id, child: Text(label));
                    }).toList(),
                    onChanged: (v) => setState(() => selectedUid = v ?? selectedUid),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: () async {
                          final t = title.text.trim();
                          final d = desc.text.trim();
                          final a = double.tryParse(amount.text.replaceAll(',', '.'));
                          if (t.isEmpty || d.isEmpty || a == null) {
                            setState(() => error = 'Please fill all fields with a valid amount.');
                            return;
                          }
                          final assigneeEmail = _currentMembers
                              .firstWhere((u) => u.id == selectedUid, orElse: () => AppUser(id: selectedUid, email: ''))
                              .email;
                          await _boeteService.addBoete(
                            title: t,
                            description: d,
                            amount: a,
                            userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
                            groupId: _selectedGroupId!,
                            assignedToUid: selectedUid,
                            assignedToEmail: assigneeEmail,
                          );
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddFromTemplates() async {
    if (_selectedGroupId == null) return;
    final selected = <String>{};
    String assignee = FirebaseAuth.instance.currentUser?.uid ?? '';
    String? error;
    List<BoeteTemplate> latestTemplates = const [];
    final templatesStream = _boeteService.watchTemplates(_selectedGroupId!);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppBottomSheet(
        childBuilder: (sheetContext, scrollController) {
          return StatefulBuilder(
            builder: (context, setState) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add from templates',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: assignee,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Assign to'),
                    items: _currentMembers.map((u) {
                      final label = (u.displayName?.isNotEmpty == true) ? u.displayName! : u.email;
                      return DropdownMenuItem(value: u.id, child: Text(label));
                    }).toList(),
                    onChanged: (v) => setState(() => assignee = v ?? assignee),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<BoeteTemplate>>(
                    stream: templatesStream,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kon templates niet laden',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  snap.error.toString(),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final templates = snap.data!;
                      latestTemplates = templates;
                      if (templates.isEmpty) {
                        return Text('No templates yet', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary));
                      }
                      return Column(
                        children: templates.map((tpl) {
                          final checked = selected.contains(tpl.id);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tpl.title, style: const TextStyle(color: AppTheme.textPrimary)),
                            subtitle: Text(tpl.description, style: const TextStyle(color: AppTheme.textSecondary)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('€${tpl.amount.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.textPrimary)),
                                const SizedBox(height: 4),
                                Icon(checked ? Icons.check_circle : Icons.circle_outlined, color: checked ? AppTheme.gold : AppTheme.textSecondary),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                if (checked) {
                                  selected.remove(tpl.id);
                                } else {
                                  selected.add(tpl.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: () async {
                          if (selected.isEmpty) {
                            setState(() => error = 'Select at least one template.');
                            return;
                          }
                          final chosen = latestTemplates.where((t) => selected.contains(t.id)).toList();
                          if (chosen.isEmpty) {
                            setState(() => error = 'Select at least one template.');
                            return;
                          }
                          final assigneeEmail = _currentMembers
                              .firstWhere((u) => u.id == assignee, orElse: () => AppUser(id: assignee, email: ''))
                              .email;
                          await _boeteService.addBoetesFromTemplates(
                            templates: chosen,
                            assignedToUid: assignee,
                            assignedToEmail: assigneeEmail,
                            groupId: _selectedGroupId!,
                            createdByEmail: FirebaseAuth.instance.currentUser?.email ?? '',
                          );
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showQuickActionsMenu({required bool isAdmin}) async {
    final renderObject = _fabKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;

    final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = renderObject.localToGlobal(renderObject.size.bottomRight(Offset.zero), ancestor: overlay);
    final position = RelativeRect.fromRect(Rect.fromPoints(topLeft, bottomRight), Offset.zero & overlay.size);

    final selected = await showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(value: 'createPot', child: Text('Nieuwe BoetePot')),
        PopupMenuItem(
          value: 'addBoete',
          enabled: _selectedGroupId != null,
          child: const Text('Add Boete'),
        ),
        PopupMenuItem(
          value: 'addFromTemplates',
          enabled: _selectedGroupId != null,
          child: const Text('Add from Templates'),
        ),
        if (isAdmin && _selectedGroupId != null)
          const PopupMenuItem(value: 'manageTemplates', child: Text('Manage Templates')),
      ],
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'createPot':
        await _showCreatePotSheet();
        break;
      case 'addBoete':
        await _showAddBoeteDialog();
        break;
      case 'addFromTemplates':
        await _showAddFromTemplates();
        break;
      case 'manageTemplates':
        if (_selectedGroupId != null && isAdmin) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TemplatesScreen(
                  groupId: _selectedGroupId!,
                  isAdmin: isAdmin,
                  currentMembers: _currentMembers,
                ),
          ));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isAdmin = _currentRoles[user.uid] == 'admin';

    return AppShell(
      topPadding: 10,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: _HeaderRow(
                  title: switch (_index) {
                    0 => 'Boetes',
                    1 => 'Betalingen',
                    2 => 'Statistieken',
                    _ => 'Profiel',
                  },
                  subtitle: _selectedGroupName,
                  onPickGroup: _openGroupPicker,
                  onSignOut: () => AuthService.signOut(),
                  roleLabel: _currentRoles[user.uid],
                  onCreatePot: _showCreatePotSheet,
                  onOpenTemplates: isAdmin && _selectedGroupId != null && (_index == 0 || _index == 1)
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TemplatesScreen(
                                  groupId: _selectedGroupId!,
                                  isAdmin: isAdmin,
                                  currentMembers: _currentMembers,
                                ),
                          ))
                      : null,
                  onOpenMembers: isAdmin && _selectedGroupId != null && (_index == 0 || _index == 1)
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => GroupMembersScreen(
                                  groupId: _selectedGroupId!,
                                  groupName: _selectedGroupName ?? '',
                                ),
                          ))
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    _buildBoetesTab(user),
                    _buildBetalingenTab(user),
                    _buildStatsTab(user),
                    _buildProfileTab(user),
                  ],
                ),
              ),
            ],
          ),
          if (_index == 0)
            Positioned(
              right: 18,
              bottom: 60 + MediaQuery.of(context).padding.bottom,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: AppTheme.gold.withAlpha(70), blurRadius: 18, spreadRadius: 2),
                  ],
                ),
                child: KeyedSubtree(
                  key: _fabKey,
                  child: GoldFab(
                    icon: Icons.add,
                    onPressed: () => _showQuickActionsMenu(isAdmin: isAdmin),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomBar: _BottomTabBar(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }

  Widget _buildBoetesTab(User user) {
    if (_selectedGroupId == null) {
      return GroupsScreen(
        onSelect: (id, name) {
          _selectGroup(uid: user.uid, id: id, name: name);
        },
      );
    }
    return BoetesScreen(
      groupId: _selectedGroupId,
      groupName: _selectedGroupName,
      currentUserEmail: user.email ?? '',
      currentUid: user.uid,
      isAdminHere: _currentRoles[user.uid] == 'admin',
      members: _currentMembers,
      roleLabel: _currentRoles[user.uid],
      onRequestGroupPicker: _openGroupPicker,
      onGroupCreated: (id, name) {
        _selectGroup(uid: user.uid, id: id, name: name);
      },
    );
  }

  Widget _buildBetalingenTab(User user) {
    if (_selectedGroupId == null) {
      return GroupsScreen(
        onSelect: (id, name) {
          _selectGroup(uid: user.uid, id: id, name: name);
        },
      );
    }
    return BetalingenScreen(
      groupId: _selectedGroupId!,
      groupName: _selectedGroupName ?? '',
      currentUid: user.uid,
      isAdminHere: _currentRoles[user.uid] == 'admin',
    );
  }

  Widget _buildStatsTab(User user) {
    if (_selectedGroupId == null) {
      return GroupsScreen(
        onSelect: (id, name) {
          _selectGroup(uid: user.uid, id: id, name: name);
        },
      );
    }
    return StatsScreen(
      groupId: _selectedGroupId!,
      currentUid: user.uid,
    );
  }

  Widget _buildProfileTab(User user) {
    return ProfileScreen(
      groupId: _selectedGroupId,
      groupName: _selectedGroupName,
      roleLabel: _currentRoles[user.uid],
      isAdminHere: _currentRoles[user.uid] == 'admin',
      onPickGroup: _openGroupPicker,
    );
  }

  void _startMembersWatch(String groupId) {
    GroupService().watchGroupMembers(groupId).listen((data) {
      setState(() {
        _currentMembers = data.members;
        _currentRoles = data.roles;
      });
    });
  }
}

class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cardStroke, width: 1),
        ),
        child: Row(
          children: [
            _tab(context, 0, Icons.list, 'Boetes'),
            _tab(context, 1, Icons.euro, 'Betalingen'),
            _tab(context, 2, Icons.bar_chart, 'Statistiek'),
            _tab(context, 3, Icons.person, 'Profiel'),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int idx, IconData icon, String label) {
    final selected = idx == index;
    final color = selected ? AppTheme.gold : AppTheme.textSecondary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onSelect(idx),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.title,
    required this.subtitle,
    required this.onPickGroup,
    required this.onSignOut,
    this.roleLabel,
    this.onCreatePot,
    this.onOpenTemplates,
    this.onOpenMembers,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onPickGroup;
  final VoidCallback onSignOut;
  final String? roleLabel;
  final VoidCallback? onCreatePot;
  final VoidCallback? onOpenTemplates;
  final VoidCallback? onOpenMembers;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onPickGroup,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cardFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardStroke, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        subtitle ?? 'Selecteer BoetePot',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (roleLabel != null) ...[
                        const SizedBox(width: 8),
                        AppPill(text: roleLabel!.toUpperCase()),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (onCreatePot != null)
          _circleButton(
            context,
            icon: Icons.add,
            tooltip: 'Nieuwe BoetePot',
            onTap: onCreatePot!,
          ),
        if (onCreatePot != null) const SizedBox(width: 8),
        if (onOpenTemplates != null)
          _circleButton(
            context,
            icon: Icons.description,
            tooltip: 'Templates',
            onTap: onOpenTemplates!,
          ),
        if (onOpenMembers != null) const SizedBox(width: 8),
        if (onOpenMembers != null)
          _circleButton(
            context,
            icon: Icons.group,
            tooltip: 'Members',
            onTap: onOpenMembers!,
          ),
        const SizedBox(width: 8),
        _circleButton(
          context,
          icon: Icons.logout,
          tooltip: 'Sign out',
          onTap: onSignOut,
        ),
      ],
    );
  }

  Widget _circleButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.cardFill,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.cardStroke, width: 1),
          ),
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}
