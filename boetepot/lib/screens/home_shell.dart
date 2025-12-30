import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/group_service.dart';
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
              setState(() {
                _selectedGroupId = id;
                _selectedGroupName = name;
              });
              _startMembersWatch(id);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isAdmin = _currentRoles[user.uid] == 'admin';

    return AppShell(
      topPadding: 10,
      body: Column(
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
          setState(() {
            _selectedGroupId = id;
            _selectedGroupName = name;
          });
          _startMembersWatch(id);
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
        setState(() {
          _selectedGroupId = id;
          _selectedGroupName = name;
        });
        _startMembersWatch(id);
      },
    );
  }

  Widget _buildBetalingenTab(User user) {
    if (_selectedGroupId == null) {
      return GroupsScreen(
        onSelect: (id, name) {
          setState(() {
            _selectedGroupId = id;
            _selectedGroupName = name;
          });
          _startMembersWatch(id);
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
          setState(() {
            _selectedGroupId = id;
            _selectedGroupName = name;
          });
          _startMembersWatch(id);
        },
      );
    }
    return StatsScreen(
      groupId: _selectedGroupId!,
      currentUid: user.uid,
    );
  }

  Widget _buildProfileTab(User user) {
    return Column(
      children: [
        Expanded(
          child: GroupsScreen(
            onSelect: (id, name) {
              setState(() {
                _selectedGroupId = id;
                _selectedGroupName = name;
              });
              _startMembersWatch(id);
            },
          ),
        ),
        const Divider(height: 1),
        const Expanded(child: ProfileScreen()),
      ],
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
    this.onOpenTemplates,
    this.onOpenMembers,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onPickGroup;
  final VoidCallback onSignOut;
  final String? roleLabel;
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
