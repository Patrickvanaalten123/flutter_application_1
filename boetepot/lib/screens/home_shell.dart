import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../models.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isAdmin = _currentRoles[user.uid] == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch (_index) {
            0 => 'Boetes',
            1 => 'Betalingen',
            2 => 'Statistiek',
            _ => 'Profiel',
          },
        ),
        actions: [
          if (_selectedGroupId != null && (_index == 0 || _index == 1 || _index == 2))
            IconButton(
              tooltip: 'Choose group',
              onPressed: () => setState(() => _index = 3), // quick way: go to Profile or Groups; but better open Groups
              icon: const Icon(Icons.folder_open),
            ),
          if (isAdmin && _selectedGroupId != null && (_index == 0 || _index == 1))
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'templates') {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TemplatesScreen(
                      groupId: _selectedGroupId!,
                      isAdmin: isAdmin,
                      currentMembers: _currentMembers,
                    ),
                  ));
                } else if (v == 'members') {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GroupMembersScreen(
                      groupId: _selectedGroupId!,
                      groupName: _selectedGroupName ?? '',
                    ),
                  ));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'templates', child: Text('Manage Templates')),
                const PopupMenuItem(value: 'members', child: Text('Manage Members')),
              ],
            ),
          IconButton(
            onPressed: () => AuthService.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          // Boetes
          _buildBoetesTab(user),
          // Betalingen
          _buildBetalingenTab(user),
          // Stats
          _buildStatsTab(user),
          // Profile (use Groups screen embedded on top to pick a group)
          _buildProfileTab(user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list), label: 'Boetes'),
          NavigationDestination(icon: Icon(Icons.euro), label: 'Betalingen'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Statistiek'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profiel'),
        ],
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