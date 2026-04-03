import 'package:flutter/material.dart';

void main() {
  runApp(const PartApprovalDesktopApp());
}

class PartApprovalDesktopApp extends StatelessWidget {
  const PartApprovalDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Part Approval Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFEDEFF7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F2430),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        fontFamily: 'SF Pro Display',
      ),
      home: const ApprovalHomePage(),
    );
  }
}

class ApprovalHomePage extends StatefulWidget {
  const ApprovalHomePage({super.key});

  @override
  State<ApprovalHomePage> createState() => _ApprovalHomePageState();
}

class _ApprovalHomePageState extends State<ApprovalHomePage> {
  bool _isLoggedIn = false;
  String _query = '';
  String _activeMenu = 'Part Request Approval';

  final List<PartRequest> _requests = demoRequests;
  PartRequest? _selectedRequest = demoRequests.first;

  List<PartRequest> get _filteredRequests {
    if (_query.isEmpty) return _requests;

    final normalized = _query.toLowerCase();
    return _requests.where((request) {
      final haystack = [
        request.idLabel,
        request.partName,
        request.brand,
        request.model,
        request.machine,
        request.category,
        request.requestedBy,
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _isLoggedIn
            ? DashboardView(
                requests: _filteredRequests,
                selectedRequest: _selectedRequest,
                activeMenu: _activeMenu,
                query: _query,
                onMenuSelected: (value) {
                  setState(() => _activeMenu = value);
                },
                onLogout: () {
                  setState(() => _isLoggedIn = false);
                },
                onSearchChanged: (value) {
                  setState(() {
                    _query = value;
                    if (!_filteredRequests.contains(_selectedRequest) &&
                        _filteredRequests.isNotEmpty) {
                      _selectedRequest = _filteredRequests.first;
                    }
                  });
                },
                onRequestSelected: (request) {
                  setState(() => _selectedRequest = request);
                },
                onStatusChanged: (request, status) {
                  setState(() {
                    request.status = status;
                    _selectedRequest = request;
                  });
                },
              )
            : LoginView(
                onLogin: () {
                  setState(() => _isLoggedIn = true);
                },
              ),
      ),
    );
  }
}

class LoginView extends StatelessWidget {
  const LoginView({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFF1F7), Color(0xFFF7F8FB), Color(0xFFECEFF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final content = compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LoginCopy(compact: compact),
                    const SizedBox(height: 24),
                    _LoginCard(onLogin: onLogin),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 32),
                        child: _LoginCopy(compact: compact),
                      ),
                    ),
                    SizedBox(width: 420, child: _LoginCard(onLogin: onLogin)),
                  ],
                );

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoginCopy extends StatelessWidget {
  const _LoginCopy({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PART APPROVAL',
          style: TextStyle(
            color: const Color(0xFF6F7685),
            fontSize: 13,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Sign in to review and\napprove part requests.',
          style: TextStyle(
            color: const Color(0xFF151820),
            fontSize: compact ? 38 : 54,
            height: 1.02,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 420 : 520),
          child: const Text(
            'Desktop-first workflow for technicians and approvers. Login opens the request list with quick status updates and approval detail.',
            style: TextStyle(
              color: Color(0xFF8A90A0),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InputBlock(
              label: 'Email',
              value: 'tech@printer-manager.com',
            ),
            const SizedBox(height: 18),
            const _InputBlock(label: 'Password', value: '••••••••••••'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2330),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.requests,
    required this.selectedRequest,
    required this.activeMenu,
    required this.query,
    required this.onMenuSelected,
    required this.onLogout,
    required this.onSearchChanged,
    required this.onRequestSelected,
    required this.onStatusChanged,
  });

  final List<PartRequest> requests;
  final PartRequest? selectedRequest;
  final String activeMenu;
  final String query;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onLogout;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PartRequest> onRequestSelected;
  final void Function(PartRequest request, ApprovalStatus status)
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final pendingCount = requests
        .where((request) => request.status != ApprovalStatus.done)
        .length;
    final outstandingTotal = requests
        .where((request) => request.status != ApprovalStatus.done)
        .fold<double>(0, (sum, request) => sum + request.cost);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactShell =
            constraints.maxWidth < 1024 || constraints.maxHeight < 760;
        final usePageScrollLayout = compactShell || constraints.maxHeight < 860;

        final dashboardContent = _DashboardContent(
          compactShell: compactShell,
          pendingCount: pendingCount,
          outstandingTotal: outstandingTotal,
          activeMenu: activeMenu,
          query: query,
          requests: requests,
          selectedRequest: selectedRequest,
          onMenuSelected: onMenuSelected,
          onLogout: onLogout,
          onSearchChanged: onSearchChanged,
          onRequestSelected: onRequestSelected,
          onStatusChanged: onStatusChanged,
          usePageScrollLayout: usePageScrollLayout,
        );

        return Container(
          color: const Color(0xFFEDEFF7),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: usePageScrollLayout
                  ? SingleChildScrollView(child: dashboardContent)
                  : dashboardContent,
            ),
          ),
        );
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.compactShell,
    required this.pendingCount,
    required this.outstandingTotal,
    required this.activeMenu,
    required this.query,
    required this.requests,
    required this.selectedRequest,
    required this.onMenuSelected,
    required this.onLogout,
    required this.onSearchChanged,
    required this.onRequestSelected,
    required this.onStatusChanged,
    required this.usePageScrollLayout,
  });

  final bool compactShell;
  final int pendingCount;
  final double outstandingTotal;
  final String activeMenu;
  final String query;
  final List<PartRequest> requests;
  final PartRequest? selectedRequest;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onLogout;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PartRequest> onRequestSelected;
  final void Function(PartRequest request, ApprovalStatus status)
  onStatusChanged;
  final bool usePageScrollLayout;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compactShell) ...[
          Sidebar(
            activeMenu: activeMenu,
            onMenuSelected: onMenuSelected,
            onLogout: onLogout,
            scrollable: usePageScrollLayout,
          ),
          const SizedBox(width: 18),
        ],
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, contentConstraints) {
                  final compactHeader = contentConstraints.maxWidth < 760;
                  final stackedPanels = contentConstraints.maxWidth < 960;

                  final metrics = compactHeader
                      ? Column(
                          children: [
                            MetricCard(
                              title: 'New + Pending Requests',
                              value: '$pendingCount',
                            ),
                            const SizedBox(height: 16),
                            MetricCard(
                              title: 'Outstanding Approval Value',
                              value:
                                  'RM ${outstandingTotal.toStringAsFixed(0)}',
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: MetricCard(
                                title: 'New + Pending Requests',
                                value: '$pendingCount',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: MetricCard(
                                title: 'Outstanding Approval Value',
                                value:
                                    'RM ${outstandingTotal.toStringAsFixed(0)}',
                              ),
                            ),
                          ],
                        );

                  final panels = stackedPanels
                      ? _buildStackedPanels()
                      : _buildSplitPanels();

                  final bodyChildren = [
                    if (compactShell) ...[
                      SidebarHeader(onLogout: onLogout),
                      const SizedBox(height: 18),
                    ],
                    _DashboardHeader(
                      onLogout: onLogout,
                      compact: compactHeader,
                    ),
                    const SizedBox(height: 18),
                    metrics,
                    const SizedBox(height: 18),
                    _Toolbar(query: query, onSearchChanged: onSearchChanged),
                    const SizedBox(height: 18),
                  ];

                  if (usePageScrollLayout) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [...bodyChildren, panels],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...bodyChildren,
                      Expanded(child: panels),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStackedPanels() {
    if (usePageScrollLayout) {
      return Column(
        children: [
          RequestListPanel(
            requests: requests,
            selectedRequest: selectedRequest,
            onRequestSelected: onRequestSelected,
            onStatusChanged: onStatusChanged,
            expandList: false,
          ),
          const SizedBox(height: 18),
          ApprovalDetailPanel(request: selectedRequest, scrollable: false),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: RequestListPanel(
            requests: requests,
            selectedRequest: selectedRequest,
            onRequestSelected: onRequestSelected,
            onStatusChanged: onStatusChanged,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(flex: 2, child: ApprovalDetailPanel(request: selectedRequest)),
      ],
    );
  }

  Widget _buildSplitPanels() {
    if (usePageScrollLayout) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: RequestListPanel(
              requests: requests,
              selectedRequest: selectedRequest,
              onRequestSelected: onRequestSelected,
              onStatusChanged: onStatusChanged,
              expandList: false,
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 300,
            child: ApprovalDetailPanel(
              request: selectedRequest,
              scrollable: false,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: RequestListPanel(
            requests: requests,
            selectedRequest: selectedRequest,
            onRequestSelected: onRequestSelected,
            onStatusChanged: onStatusChanged,
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 300,
          child: ApprovalDetailPanel(request: selectedRequest),
        ),
      ],
    );
  }
}

class SidebarHeader extends StatelessWidget {
  const SidebarHeader({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF16181D),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'PA',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Part Approval Dashboard',
            style: TextStyle(
              color: Color(0xFF16181D),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: onLogout,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF3C4352),
            side: const BorderSide(color: Color(0xFFE3E6EF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.activeMenu,
    required this.onMenuSelected,
    required this.onLogout,
    this.scrollable = false,
  });

  final String activeMenu;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onLogout;
  final bool scrollable;

  static const items = [
    'Store management',
    'Part Request Approval',
    'Pending',
    'Returned',
    'Reports',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final sidebarContent = Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF16181D),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              'PA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'MENU',
            style: TextStyle(
              color: Color(0xFF98A0AE),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _SidebarItem(
                label: item,
                selected: item == activeMenu,
                onTap: () => onMenuSelected(item),
              ),
            ),
          ),
          if (scrollable) const SizedBox(height: 18) else const Spacer(),
          const Divider(height: 24, color: Color(0xFFE8EBF2)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 0,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE8EBF2),
              child: const Text(
                'A',
                style: TextStyle(
                  color: Color(0xFF2C3442),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: const Text(
              'Aisyah | Approver',
              style: TextStyle(
                color: Color(0xFF3C4352),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'tech@printer-manager.com',
              style: TextStyle(color: Color(0xFF8A90A0), fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3C4352),
                side: const BorderSide(color: Color(0xFFE3E6EF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: scrollable
          ? SingleChildScrollView(child: sidebarContent)
          : sidebarContent,
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF3F5FA) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF1A202C)
                  : const Color(0xFF6C7280),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onLogout, required this.compact});

  final VoidCallback onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleBlock = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Part Request Approval',
          style: TextStyle(
            color: Color(0xFF16181D),
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Monitor incoming requests and update approval status without leaving the list.',
          style: TextStyle(color: Color(0xFF818898), fontSize: 13),
        ),
      ],
    );

    final userBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E6EF)),
      ),
      child: const Text(
        'Aisyah | Approver',
        style: TextStyle(
          color: Color(0xFF3C4352),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleBlock, const SizedBox(height: 12), userBadge],
      );
    }

    return Row(
      children: [
        Expanded(child: titleBlock),
        userBadge,
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF171A20),
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF525A6A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.query, required this.onSearchChanged});

  final String query;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        final searchBox = Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3E6EF)),
          ),
          alignment: Alignment.center,
          child: TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Search by part name, machine, category, or user',
              hintStyle: TextStyle(color: Color(0xFF98A0AE), fontSize: 13),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: Color(0xFF98A0AE),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );

        if (compact) {
          return Column(
            children: [
              searchBox,
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToolbarChip(
                      label: 'Filters: Status, Category, Machine, Date',
                    ),
                    _ToolbarChip(label: 'New Request'),
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchBox),
            const SizedBox(width: 12),
            const _ToolbarChip(
              label: 'Filters: Status, Category, Machine, Date',
            ),
            const SizedBox(width: 8),
            const _ToolbarChip(label: 'New Request'),
          ],
        );
      },
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E6EF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF596071),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class RequestListPanel extends StatelessWidget {
  const RequestListPanel({
    super.key,
    required this.requests,
    required this.selectedRequest,
    required this.onRequestSelected,
    required this.onStatusChanged,
    this.expandList = true,
  });

  final List<PartRequest> requests;
  final PartRequest? selectedRequest;
  final ValueChanged<PartRequest> onRequestSelected;
  final void Function(PartRequest request, ApprovalStatus status)
  onStatusChanged;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    final listContent = requests.isEmpty
        ? const Center(
            child: Text(
              'No requests matched your search.',
              style: TextStyle(color: Color(0xFF8A90A0), fontSize: 14),
            ),
          )
        : ListView.separated(
            shrinkWrap: !expandList,
            physics: expandList
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final request = requests[index];
              return RequestRowCard(
                request: request,
                selected: selectedRequest?.id == request.id,
                onTap: () => onRequestSelected(request),
                onStatusChanged: (status) => onStatusChanged(request, status),
              );
            },
          );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Part Request List',
              style: TextStyle(
                color: Color(0xFF16181D),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            if (expandList) Expanded(child: listContent) else listContent,
          ],
        ),
      ),
    );
  }
}

class RequestRowCard extends StatelessWidget {
  const RequestRowCard({
    super.key,
    required this.request,
    required this.selected,
    required this.onTap,
    required this.onStatusChanged,
  });

  final PartRequest request;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<ApprovalStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        final requestInfo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.idLabel}  |  ${request.partName}',
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1E2431),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${request.brand}  |  ${request.model}  |  ${request.machine}  |  ${request.category}',
              maxLines: compact ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF657082), fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              'Requested by ${request.requestedBy}  |  RM ${request.cost.toStringAsFixed(0)}  |  ${request.createdAt}',
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF657082), fontSize: 12),
            ),
          ],
        );

        final statusWrap = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ApprovalStatus.values.map((status) {
            return StatusChip(
              label: status.label,
              active: request.status == status,
              style: status.style,
              onTap: () => onStatusChanged(status),
            );
          }).toList(),
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFCAD3E5)
                      : const Color(0xFFECEEF4),
                ),
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        requestInfo,
                        const SizedBox(height: 12),
                        statusWrap,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: requestInfo),
                        const SizedBox(width: 16),
                        Flexible(child: statusWrap),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.active,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool active;
  final StatusChipStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? style.background
              : style.background.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: style.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: style.foreground,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class ApprovalDetailPanel extends StatelessWidget {
  const ApprovalDetailPanel({
    super.key,
    required this.request,
    this.scrollable = true,
  });

  final PartRequest? request;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final detailContent = request == null
        ? const Center(
            child: Text(
              'Select a request to view detail.',
              style: TextStyle(color: Color(0xFF8A90A0), fontSize: 14),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Approval Detail',
                style: TextStyle(
                  color: Color(0xFF16181D),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              DetailCard(
                title: 'Selected: ${request!.idLabel}',
                body:
                    '${request!.partName} is waiting for approver action. The quick chips on the left can update status to New, Pending, Done, or Returned instantly.',
              ),
              const SizedBox(height: 12),
              DetailCard(
                title: 'Request Info',
                body:
                    'Brand: ${request!.brand}\nModel: ${request!.model}\nMachine: ${request!.machine}\nPart Category: ${request!.category}\nCost: RM ${request!.cost.toStringAsFixed(0)}\nRequested By: ${request!.requestedBy}\nCreated At: ${request!.createdAt}',
              ),
              const SizedBox(height: 12),
              DetailCard(title: 'Remark', body: request!.remark),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2430),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'API contract:\nGET /api/mobile/part-request\nPUT /api/mobile/part-request/{id}\nPOST /api/mobile/search/part-requests\nPOST /api/mobile/part-request',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const DetailCard(
                title: 'Desktop Flutter Direction',
                body:
                    'Login screen, wide request list, fast status actions for each row, and a persistent detail panel for day-to-day approvals.',
              ),
            ],
          );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: scrollable
            ? SingleChildScrollView(child: detailContent)
            : detailContent,
      ),
    );
  }
}

class DetailCard extends StatelessWidget {
  const DetailCard({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEEF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF4F5666),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF566072),
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBlock extends StatelessWidget {
  const _InputBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF566072), fontSize: 15),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(color: Color(0xFF566072), fontSize: 15),
        ),
      ],
    );
  }
}

enum ApprovalStatus {
  newRequest('New (1)'),
  pending('Pending (2)'),
  done('Done (3)'),
  returned('Returned (4)');

  const ApprovalStatus(this.label);

  final String label;

  StatusChipStyle get style {
    switch (this) {
      case ApprovalStatus.newRequest:
        return const StatusChipStyle(
          background: Color(0xFFF3F7FF),
          border: Color(0xFFD9E5FF),
          foreground: Color(0xFF4A6ACF),
        );
      case ApprovalStatus.pending:
        return const StatusChipStyle(
          background: Color(0xFFFFF8E6),
          border: Color(0xFFF4DE9D),
          foreground: Color(0xFFA37500),
        );
      case ApprovalStatus.done:
        return const StatusChipStyle(
          background: Color(0xFFEEF9F1),
          border: Color(0xFFCFEAD5),
          foreground: Color(0xFF2E7A46),
        );
      case ApprovalStatus.returned:
        return const StatusChipStyle(
          background: Color(0xFFFFF0F0),
          border: Color(0xFFF0C7C7),
          foreground: Color(0xFFA65A5A),
        );
    }
  }
}

class StatusChipStyle {
  const StatusChipStyle({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

class PartRequest {
  PartRequest({
    required this.id,
    required this.partName,
    required this.brand,
    required this.model,
    required this.machine,
    required this.category,
    required this.requestedBy,
    required this.cost,
    required this.createdAt,
    required this.remark,
    required this.status,
  });

  final int id;
  final String partName;
  final String brand;
  final String model;
  final String machine;
  final String category;
  final String requestedBy;
  final double cost;
  final String createdAt;
  final String remark;
  ApprovalStatus status;

  String get idLabel => 'PR-$id';
}

final demoRequests = <PartRequest>[
  PartRequest(
    id: 5001,
    partName: 'Cyan Drum Kit',
    brand: 'Canon',
    model: 'iR ADV DX C3926',
    machine: 'HQ Printer A',
    category: 'Drum Unit',
    requestedBy: 'Aisyah',
    cost: 780,
    createdAt: '2026-04-02',
    remark:
        'Need urgent approval before next PM cycle. Drum count is high and print quality shows repeated marks.',
    status: ApprovalStatus.newRequest,
  ),
  PartRequest(
    id: 5002,
    partName: 'Upper Fuser Roller',
    brand: 'Fuji Xerox',
    model: 'Apeos C7070',
    machine: 'Branch Copier 02',
    category: 'Fuser Assembly',
    requestedBy: 'Farhan',
    cost: 1260,
    createdAt: '2026-04-01',
    remark:
        'Temperature inconsistency is causing wrinkled output. Vendor quote is already attached in the backend.',
    status: ApprovalStatus.pending,
  ),
  PartRequest(
    id: 5003,
    partName: 'Pickup Roller Set',
    brand: 'Ricoh',
    model: 'IM C3000',
    machine: 'Warehouse Unit 4',
    category: 'Paper Feed',
    requestedBy: 'Nina',
    cost: 180,
    createdAt: '2026-03-29',
    remark:
        'Replacement request submitted after repeated tray misfeeds during preventive maintenance.',
    status: ApprovalStatus.done,
  ),
];
