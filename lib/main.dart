import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'part_request_api.dart';

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
  static const _refreshInterval = Duration(seconds: 20);

  final PartRequestApi _api = PartRequestApi();
  final TextEditingController _emailController = TextEditingController(
    text: 'tech@printer-manager.com',
  );
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoggedIn = false;
  bool _isLoggingIn = false;
  bool _isLoadingRequests = false;
  bool _isUpdatingStatus = false;
  String _query = '';
  String _activeMenu = 'Part Request Approval';
  String? _selectedRequester;
  ApprovalStatus? _selectedStatus;
  String? _loginError;
  String? _requestError;
  DateTime? _lastUpdatedAt;
  Timer? _refreshTimer;

  List<PartRequest> _requests = const [];
  PartRequest? _selectedRequest;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoggingIn = true;
      _loginError = null;
    });

    try {
      await _api.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      setState(() {
        _isLoggedIn = true;
      });

      await _loadRequests(showSnackBar: false);
      _startAutoRefresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loginError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _loginError = 'Unable to sign in. ${_friendlyLoginFailure(error)}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  Future<void> _loadRequests({
    bool silent = false,
    bool showSnackBar = true,
  }) async {
    if (_isLoadingRequests) return;

    if (!silent) {
      setState(() {
        _isLoadingRequests = true;
        _requestError = null;
      });
    }

    try {
      final payload = await _api.listPartRequests();
      final requests = payload.map(PartRequest.fromJson).toList()
        ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
      final previousIds = _requests.map((item) => item.id).toSet();
      final newItems = requests
          .where((item) => !previousIds.contains(item.id))
          .length;
      final nextSelected = _resolveSelectedRequest(requests);

      if (!mounted) return;

      final menuScopedRequests = _filterRequestsByActiveMenu(requests);

      setState(() {
        _requests = requests;
        _selectedRequester = _resolveSelectedRequester(menuScopedRequests);
        _selectedStatus = _resolveSelectedStatus(menuScopedRequests);
        _selectedRequest = nextSelected;
        _lastUpdatedAt = DateTime.now();
        _requestError = null;
      });

      if (showSnackBar) {
        final message = newItems > 0
            ? 'Request list refreshed. $newItems new request${newItems == 1 ? '' : 's'} found.'
            : 'Request list refreshed';
        _showSnackBar(message);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _requestError = error.message);
      if (showSnackBar) {
        _showSnackBar(error.message);
      }
    } catch (_) {
      if (!mounted) return;
      const fallbackMessage = 'Unable to load part requests right now.';
      setState(() => _requestError = fallbackMessage);
      if (showSnackBar) {
        _showSnackBar(fallbackMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  Future<void> _handleStatusChanged(
    PartRequest request,
    ApprovalStatus status,
  ) async {
    if (_isUpdatingStatus || request.status == status) return;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm status change'),
          content: Text(
            'Approver confirmation is required.\n\nChange ${request.idLabel} from ${request.status.label} to ${status.label}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (approved != true || !mounted) return;

    PartRequest requestForUpdate = request;

    if (!request.hasRequiredUpdateIds) {
      try {
        final detail = await _api.showPartRequest(request.id);
        requestForUpdate = PartRequest.fromJson(
          detail,
        ).mergeWithFallback(request);
      } on ApiException catch (error) {
        if (!mounted) return;
        _showSnackBar(error.message);
        return;
      } catch (_) {
        if (!mounted) return;
        _showSnackBar('Unable to load the latest request details.');
        return;
      }
    }

    final originalStatus = request.status;
    setState(() {
      _isUpdatingStatus = true;
      request.status = status;
      _selectedRequest = request;
    });

    try {
      final response = await _api.updatePartRequest(
        requestForUpdate.id,
        requestForUpdate.toUpdatePayload(status),
      );

      final updated = PartRequest.fromJson(response).mergeWithFallback(request);

      if (!mounted) return;

      setState(() {
        _replaceRequest(updated);
        _selectedRequest = updated;
      });
      _showSnackBar('Status updated to ${status.shortLabel}.');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        request.status = originalStatus;
      });
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        request.status = originalStatus;
      });
      _showSnackBar('Unable to update the request status.');
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  void _replaceRequest(PartRequest updated) {
    final index = _requests.indexWhere((item) => item.id == updated.id);
    if (index == -1) return;
    final next = [..._requests];
    next[index] = updated;
    _requests = next;
  }

  PartRequest? _resolveSelectedRequest(List<PartRequest> requests) {
    if (requests.isEmpty) return null;
    final selectedId = _selectedRequest?.id;
    if (selectedId == null) return requests.first;
    return requests.cast<PartRequest?>().firstWhere(
      (item) => item?.id == selectedId,
      orElse: () => requests.first,
    );
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _loadRequests(silent: true, showSnackBar: false);
    });
  }

  void _handleLogout() {
    _refreshTimer?.cancel();
    setState(() {
      _isLoggedIn = false;
      _isLoggingIn = false;
      _isLoadingRequests = false;
      _isUpdatingStatus = false;
      _query = '';
      _requestError = null;
      _loginError = null;
      _lastUpdatedAt = null;
      _selectedRequester = null;
      _requests = const [];
      _selectedRequest = null;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _showRequestDetailDialog(PartRequest request) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final dialogWidth = size.width < 720 ? size.width - 32 : 640.0;
        final dialogHeight = size.height < 820 ? size.height * 0.8 : 720.0;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: dialogHeight,
            ),
            child: ApprovalDetailPanel(
              request: request,
              lastUpdatedAt: _lastUpdatedAt,
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        );
      },
    );
  }

  List<PartRequest> _filterRequestsByActiveMenu(List<PartRequest> requests) {
    return switch (_activeMenu) {
      'Pending' =>
        requests
            .where((request) => request.status == ApprovalStatus.pending)
            .toList(),
      'Returned' =>
        requests
            .where((request) => request.status == ApprovalStatus.returned)
            .toList(),
      _ => requests,
    };
  }

  List<PartRequest> get _menuScopedRequests =>
      _filterRequestsByActiveMenu(_requests);

  List<String> get _requestedByOptions {
    final names = _requestedByCounts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Map<String, int> get _requestedByCounts {
    final counts = <String, int>{};

    for (final request in _menuScopedRequests) {
      final name = request.requestedBy.trim();
      if (name.isEmpty || name == '-') continue;
      counts.update(name, (value) => value + 1, ifAbsent: () => 1);
    }

    return counts;
  }

  Map<ApprovalStatus, int> get _statusCounts {
    final counts = <ApprovalStatus, int>{
      for (final status in ApprovalStatus.values) status: 0,
    };

    for (final request in _menuScopedRequests) {
      counts.update(request.status, (value) => value + 1);
    }

    return counts;
  }

  String? _resolveSelectedRequester(List<PartRequest> requests) {
    final availableRequesters = requests
        .map((request) => request.requestedBy.trim())
        .where((name) => name.isNotEmpty && name != '-')
        .toSet();

    final selectedRequester = _selectedRequester;
    if (selectedRequester == null) return null;
    if (availableRequesters.contains(selectedRequester)) {
      return selectedRequester;
    }
    return null;
  }

  ApprovalStatus? _resolveSelectedStatus(List<PartRequest> requests) {
    final selectedStatus = _selectedStatus;
    if (selectedStatus == null) return null;

    final availableStatuses = requests.map((request) => request.status).toSet();
    if (availableStatuses.contains(selectedStatus)) return selectedStatus;
    return null;
  }

  List<PartRequest> get _filteredRequests {
    final base = _menuScopedRequests;

    final statusFiltered = _selectedStatus == null
        ? base
        : base.where((request) => request.status == _selectedStatus).toList();

    final requesterFiltered = _selectedRequester == null
        ? statusFiltered
        : statusFiltered
              .where((request) => request.requestedBy == _selectedRequester)
              .toList();

    if (_query.isEmpty) return requesterFiltered;

    final normalized = _query.toLowerCase();
    return requesterFiltered.where((request) {
      final haystack = [
        request.idLabel,
        request.partName,
        request.brand,
        request.model,
        request.machine,
        request.category,
        request.requestedBy,
        request.description,
        request.remark,
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
                allRequests: _requests,
                selectedRequest: _selectedRequest,
                activeMenu: _activeMenu,
                requesterOptions: _requestedByOptions,
                requesterCounts: _requestedByCounts,
                selectedRequester: _selectedRequester,
                statusCounts: _statusCounts,
                selectedStatus: _selectedStatus,
                query: _query,
                isLoadingRequests: _isLoadingRequests,
                isUpdatingStatus: _isUpdatingStatus,
                requestError: _requestError,
                lastUpdatedAt: _lastUpdatedAt,
                refreshInterval: _refreshInterval,
                onMenuSelected: (value) {
                  setState(() {
                    _activeMenu = value;
                    _selectedRequester = _resolveSelectedRequester(
                      _menuScopedRequests,
                    );
                    _selectedStatus = _resolveSelectedStatus(
                      _menuScopedRequests,
                    );
                    _selectedRequest = _resolveSelectedRequest(
                      _filteredRequests,
                    );
                  });
                },
                onLogout: _handleLogout,
                onSearchChanged: (value) {
                  setState(() {
                    _query = value;
                    _selectedRequest = _resolveSelectedRequest(
                      _filteredRequests,
                    );
                  });
                },
                onRequesterSelected: (value) {
                  setState(() {
                    _selectedRequester = value;
                    _selectedRequest = _resolveSelectedRequest(
                      _filteredRequests,
                    );
                  });
                },
                onStatusFilterSelected: (value) {
                  setState(() {
                    _selectedStatus = value;
                    _selectedRequest = _resolveSelectedRequest(
                      _filteredRequests,
                    );
                  });
                },
                onRequestSelected: (request) {
                  setState(() => _selectedRequest = request);
                  _showRequestDetailDialog(request);
                },
                onStatusChanged: _handleStatusChanged,
                onRefresh: () => _loadRequests(),
              )
            : LoginView(
                emailController: _emailController,
                passwordController: _passwordController,
                isLoading: _isLoggingIn,
                errorMessage: _loginError,
                onLogin: _handleLogin,
              ),
      ),
    );
  }
}

class LoginView extends StatelessWidget {
  const LoginView({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.errorMessage,
    required this.onLogin,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final String? errorMessage;
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
                    _LoginCard(
                      emailController: emailController,
                      passwordController: passwordController,
                      isLoading: isLoading,
                      errorMessage: errorMessage,
                      onLogin: onLogin,
                    ),
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
                    SizedBox(
                      width: 420,
                      child: _LoginCard(
                        emailController: emailController,
                        passwordController: passwordController,
                        isLoading: isLoading,
                        errorMessage: errorMessage,
                        onLogin: onLogin,
                      ),
                    ),
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
        const Text(
          'PART APPROVAL',
          style: TextStyle(
            color: Color(0xFF6F7685),
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
          child: Text(
            kIsWeb
                ? 'This project should connect to the WOD mobile API, but browser login can be blocked by the backend CSRF policy. For the same behavior as WOD, run it as a desktop app on macOS, Windows, or Linux.'
                : 'This desktop client now authenticates against the live mobile API, loads /api/mobile/part-request, and auto-refreshes so new requests submitted from another platform appear here without a restart.',
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
  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.errorMessage,
    required this.onLogin,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final String? errorMessage;
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
            _EditableInputBlock(
              label: 'Email',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => onLogin(),
            ),
            const SizedBox(height: 18),
            _EditableInputBlock(
              label: 'Password',
              controller: passwordController,
              obscureText: true,
              onSubmitted: (_) => onLogin(),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFA63D40),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : onLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2330),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
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
    required this.allRequests,
    required this.selectedRequest,
    required this.activeMenu,
    required this.requesterOptions,
    required this.requesterCounts,
    required this.selectedRequester,
    required this.statusCounts,
    required this.selectedStatus,
    required this.query,
    required this.isLoadingRequests,
    required this.isUpdatingStatus,
    required this.requestError,
    required this.lastUpdatedAt,
    required this.refreshInterval,
    required this.onMenuSelected,
    required this.onLogout,
    required this.onSearchChanged,
    required this.onRequesterSelected,
    required this.onStatusFilterSelected,
    required this.onRequestSelected,
    required this.onStatusChanged,
    required this.onRefresh,
  });

  final List<PartRequest> requests;
  final List<PartRequest> allRequests;
  final PartRequest? selectedRequest;
  final String activeMenu;
  final List<String> requesterOptions;
  final Map<String, int> requesterCounts;
  final String? selectedRequester;
  final Map<ApprovalStatus, int> statusCounts;
  final ApprovalStatus? selectedStatus;
  final String query;
  final bool isLoadingRequests;
  final bool isUpdatingStatus;
  final String? requestError;
  final DateTime? lastUpdatedAt;
  final Duration refreshInterval;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onLogout;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRequesterSelected;
  final ValueChanged<ApprovalStatus?> onStatusFilterSelected;
  final ValueChanged<PartRequest> onRequestSelected;
  final void Function(PartRequest request, ApprovalStatus status)
  onStatusChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final pendingCount = allRequests
        .where((request) => !request.status.isClosed)
        .length;
    final outstandingTotal = allRequests
        .where((request) => !request.status.isClosed)
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
          requesterOptions: requesterOptions,
          requesterCounts: requesterCounts,
          selectedRequester: selectedRequester,
          statusCounts: statusCounts,
          selectedStatus: selectedStatus,
          query: query,
          requests: requests,
          selectedRequest: selectedRequest,
          isLoadingRequests: isLoadingRequests,
          isUpdatingStatus: isUpdatingStatus,
          requestError: requestError,
          lastUpdatedAt: lastUpdatedAt,
          refreshInterval: refreshInterval,
          onMenuSelected: onMenuSelected,
          onLogout: onLogout,
          onSearchChanged: onSearchChanged,
          onRequesterSelected: onRequesterSelected,
          onStatusFilterSelected: onStatusFilterSelected,
          onRequestSelected: onRequestSelected,
          onStatusChanged: onStatusChanged,
          onRefresh: onRefresh,
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
    required this.requesterOptions,
    required this.requesterCounts,
    required this.selectedRequester,
    required this.statusCounts,
    required this.selectedStatus,
    required this.query,
    required this.requests,
    required this.selectedRequest,
    required this.isLoadingRequests,
    required this.isUpdatingStatus,
    required this.requestError,
    required this.lastUpdatedAt,
    required this.refreshInterval,
    required this.onMenuSelected,
    required this.onLogout,
    required this.onSearchChanged,
    required this.onRequesterSelected,
    required this.onStatusFilterSelected,
    required this.onRequestSelected,
    required this.onStatusChanged,
    required this.onRefresh,
    required this.usePageScrollLayout,
  });

  final bool compactShell;
  final int pendingCount;
  final double outstandingTotal;
  final String activeMenu;
  final List<String> requesterOptions;
  final Map<String, int> requesterCounts;
  final String? selectedRequester;
  final Map<ApprovalStatus, int> statusCounts;
  final ApprovalStatus? selectedStatus;
  final String query;
  final List<PartRequest> requests;
  final PartRequest? selectedRequest;
  final bool isLoadingRequests;
  final bool isUpdatingStatus;
  final String? requestError;
  final DateTime? lastUpdatedAt;
  final Duration refreshInterval;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onLogout;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRequesterSelected;
  final ValueChanged<ApprovalStatus?> onStatusFilterSelected;
  final ValueChanged<PartRequest> onRequestSelected;
  final void Function(PartRequest request, ApprovalStatus status)
  onStatusChanged;
  final VoidCallback onRefresh;
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
                  final metrics = compactHeader
                      ? Column(
                          children: [
                            MetricCard(
                              title: 'Open Requests',
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
                                title: 'Open Requests',
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

                  final panels = _RequestSection(
                    requests: requests,
                    requesterOptions: requesterOptions,
                    requesterCounts: requesterCounts,
                    selectedRequester: selectedRequester,
                    statusCounts: statusCounts,
                    selectedStatus: selectedStatus,
                    selectedRequest: selectedRequest,
                    isLoadingRequests: isLoadingRequests,
                    isUpdatingStatus: isUpdatingStatus,
                    onRequesterSelected: onRequesterSelected,
                    onStatusFilterSelected: onStatusFilterSelected,
                    onRequestSelected: onRequestSelected,
                    onStatusChanged: onStatusChanged,
                    compact: compactHeader,
                    expandList: !usePageScrollLayout,
                  );

                  final bodyChildren = [
                    if (compactShell) ...[
                      SidebarHeader(onLogout: onLogout),
                      const SizedBox(height: 18),
                    ],
                    _DashboardHeader(
                      onLogout: onLogout,
                      onRefresh: onRefresh,
                      compact: compactHeader,
                      isLoadingRequests: isLoadingRequests,
                      lastUpdatedAt: lastUpdatedAt,
                      refreshInterval: refreshInterval,
                    ),
                    const SizedBox(height: 18),
                    metrics,
                    const SizedBox(height: 18),
                    _Toolbar(query: query, onSearchChanged: onSearchChanged),
                    if (requestError != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: requestError!),
                    ],
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
  const _DashboardHeader({
    required this.onLogout,
    required this.onRefresh,
    required this.compact,
    required this.isLoadingRequests,
    required this.lastUpdatedAt,
    required this.refreshInterval,
  });

  final VoidCallback onLogout;
  final VoidCallback onRefresh;
  final bool compact;
  final bool isLoadingRequests;
  final DateTime? lastUpdatedAt;
  final Duration refreshInterval;

  @override
  Widget build(BuildContext context) {
    final subtitle = lastUpdatedAt == null
        ? 'Waiting for first sync.'
        : 'Auto-refresh every ${refreshInterval.inSeconds}s. Last sync ${_formatTime(lastUpdatedAt!)}.';

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Part Request Approval',
          style: TextStyle(
            color: Color(0xFF16181D),
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF818898), fontSize: 13),
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

    final refreshButton = OutlinedButton.icon(
      onPressed: isLoadingRequests ? null : onRefresh,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF3C4352),
        side: const BorderSide(color: Color(0xFFE3E6EF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      icon: isLoadingRequests
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh, size: 18),
      label: Text(
        isLoadingRequests ? 'Refreshing' : 'Refresh',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: userBadge),
              const SizedBox(width: 12),
              refreshButton,
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titleBlock),
        refreshButton,
        const SizedBox(width: 12),
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
            controller: TextEditingController(text: query)
              ..selection = TextSelection.collapsed(offset: query.length),
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
          return searchBox;
        }

        return Row(children: [Expanded(child: searchBox)]);
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2D0C7)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF8C3C2E),
          fontSize: 13,
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
    required this.isLoadingRequests,
    required this.isUpdatingStatus,
    required this.statusCounts,
    required this.selectedStatus,
    required this.onStatusFilterSelected,
    required this.onRequestSelected,
    required this.onStatusChanged,
    this.expandList = true,
  });

  final List<PartRequest> requests;
  final PartRequest? selectedRequest;
  final bool isLoadingRequests;
  final bool isUpdatingStatus;
  final Map<ApprovalStatus, int> statusCounts;
  final ApprovalStatus? selectedStatus;
  final ValueChanged<ApprovalStatus?> onStatusFilterSelected;
  final ValueChanged<PartRequest> onRequestSelected;
  final void Function(PartRequest request, ApprovalStatus status)
  onStatusChanged;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    final groupedRequests = _groupRequestsByDate(requests);
    final listContent = requests.isEmpty
        ? Center(
            child: Text(
              isLoadingRequests
                  ? 'Loading requests from /api/mobile/part-request...'
                  : 'No requests matched your search.',
              style: const TextStyle(color: Color(0xFF8A90A0), fontSize: 14),
            ),
          )
        : Stack(
            children: [
              CustomScrollView(
                shrinkWrap: !expandList,
                physics: expandList
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                slivers: [
                  for (final group in groupedRequests) ...[
                    SliverPersistentHeader(
                      pinned: expandList,
                      delegate: _StickyDateHeaderDelegate(
                        label: _formatRequestSectionDate(group.date),
                      ),
                    ),
                    SliverList.separated(
                      itemCount: group.requests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final request = group.requests[index];
                        return RequestRowCard(
                          request: request,
                          selected: selectedRequest?.id == request.id,
                          isBusy: isUpdatingStatus,
                          onTap: () => onRequestSelected(request),
                          onStatusChanged: (status) =>
                              onStatusChanged(request, status),
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                ],
              ),
              if (isLoadingRequests && requests.isNotEmpty)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final filterChips = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusFilterChip(
                      label: 'All',
                      count: statusCounts.values.fold<int>(
                        0,
                        (sum, count) => sum + count,
                      ),
                      selected: selectedStatus == null,
                      onTap: () => onStatusFilterSelected(null),
                    ),
                    ...ApprovalStatus.values.map(
                      (status) => _StatusFilterChip(
                        label: status.label,
                        count: statusCounts[status] ?? 0,
                        selected: selectedStatus == status,
                        style: status.style,
                        onTap: () => onStatusFilterSelected(status),
                      ),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
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
                      const SizedBox(height: 12),
                      filterChips,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        'Part Request List',
                        style: TextStyle(
                          color: Color(0xFF16181D),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(child: filterChips),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            if (expandList) Expanded(child: listContent) else listContent,
          ],
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.style,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final StatusChipStyle? style;

  @override
  Widget build(BuildContext context) {
    final activeStyle =
        style ??
        const StatusChipStyle(
          background: Color(0xFFF3F5FA),
          border: Color(0xFFD9DEEA),
          foreground: Color(0xFF364152),
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? activeStyle.background : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? activeStyle.border : const Color(0xFFE1E5EF),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? activeStyle.foreground
                      : const Color(0xFF5F6777),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? activeStyle.border.withValues(alpha: 0.45)
                      : const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected
                        ? activeStyle.foreground
                        : const Color(0xFF697386),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestSection extends StatelessWidget {
  const _RequestSection({
    required this.requests,
    required this.requesterOptions,
    required this.requesterCounts,
    required this.selectedRequester,
    required this.statusCounts,
    required this.selectedStatus,
    required this.selectedRequest,
    required this.isLoadingRequests,
    required this.isUpdatingStatus,
    required this.onRequesterSelected,
    required this.onStatusFilterSelected,
    required this.onRequestSelected,
    required this.onStatusChanged,
    required this.compact,
    required this.expandList,
  });

  final List<PartRequest> requests;
  final List<String> requesterOptions;
  final Map<String, int> requesterCounts;
  final String? selectedRequester;
  final Map<ApprovalStatus, int> statusCounts;
  final ApprovalStatus? selectedStatus;
  final PartRequest? selectedRequest;
  final bool isLoadingRequests;
  final bool isUpdatingStatus;
  final ValueChanged<String?> onRequesterSelected;
  final ValueChanged<ApprovalStatus?> onStatusFilterSelected;
  final ValueChanged<PartRequest> onRequestSelected;
  final void Function(PartRequest request, ApprovalStatus status)
  onStatusChanged;
  final bool compact;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    final requestList = RequestListPanel(
      requests: requests,
      selectedRequest: selectedRequest,
      isLoadingRequests: isLoadingRequests,
      isUpdatingStatus: isUpdatingStatus,
      statusCounts: statusCounts,
      selectedStatus: selectedStatus,
      onStatusFilterSelected: onStatusFilterSelected,
      onRequestSelected: onRequestSelected,
      onStatusChanged: onStatusChanged,
      expandList: expandList,
    );

    final requesterPanel = RequestedByFilterPanel(
      requesterOptions: requesterOptions,
      requesterCounts: requesterCounts,
      selectedRequester: selectedRequester,
      onRequesterSelected: onRequesterSelected,
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [requesterPanel, const SizedBox(height: 16), requestList],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 240, child: requesterPanel),
        const SizedBox(width: 16),
        Expanded(child: requestList),
      ],
    );
  }
}

class RequestedByFilterPanel extends StatelessWidget {
  const RequestedByFilterPanel({
    super.key,
    required this.requesterOptions,
    required this.requesterCounts,
    required this.selectedRequester,
    required this.onRequesterSelected,
  });

  final List<String> requesterOptions;
  final Map<String, int> requesterCounts;
  final String? selectedRequester;
  final ValueChanged<String?> onRequesterSelected;

  @override
  Widget build(BuildContext context) {
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
              'Requested By',
              style: TextStyle(
                color: Color(0xFF16181D),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Filter the part request list by requester.',
              style: const TextStyle(color: Color(0xFF818898), fontSize: 13),
            ),
            const SizedBox(height: 14),
            _RequestedByFilterItem(
              label: 'All Users',
              count: requesterCounts.values.fold<int>(
                0,
                (sum, count) => sum + count,
              ),
              selected: selectedRequester == null,
              onTap: () => onRequesterSelected(null),
            ),
            if (requesterOptions.isEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'No requester names available yet.',
                style: TextStyle(color: Color(0xFF8A90A0), fontSize: 13),
              ),
            ] else ...[
              const SizedBox(height: 10),
              ...requesterOptions.map(
                (requester) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RequestedByFilterItem(
                    label: requester,
                    count: requesterCounts[requester] ?? 0,
                    selected: requester == selectedRequester,
                    onTap: () => onRequesterSelected(requester),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestedByFilterItem extends StatelessWidget {
  const _RequestedByFilterItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF3F5FA) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF1A202C)
                        : const Color(0xFF5F6777),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE1E7F5)
                        : const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Color(0xFF4F5666),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyDateHeaderDelegate({required this.label});

  final String label;

  @override
  double get minExtent => 40;

  @override
  double get maxExtent => 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: overlapsContent
              ? const Color(0xFFEFF4FF)
              : const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: overlapsContent
                ? const Color(0xFFC8D6F2)
                : const Color(0xFFD7E1F2),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF24324A),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyDateHeaderDelegate oldDelegate) {
    return oldDelegate.label != label;
  }
}

class RequestRowCard extends StatelessWidget {
  const RequestRowCard({
    super.key,
    required this.request,
    required this.selected,
    required this.isBusy,
    required this.onTap,
    required this.onStatusChanged,
  });

  final PartRequest request;
  final bool selected;
  final bool isBusy;
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
              enabled: !isBusy,
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
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool active;
  final StatusChipStyle style;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active
        ? const Color(0xFF1E2431)
        : const Color(0xFF667085);
    final background = active
        ? const Color(0xFFF6F7FB)
        : const Color(0xFFFFFFFF);
    final border = active ? const Color(0xFFBFC6D4) : const Color(0xFFD9DEE8);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              Icon(Icons.check_rounded, size: 14, color: foreground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ApprovalDetailPanel extends StatelessWidget {
  const ApprovalDetailPanel({
    super.key,
    required this.request,
    required this.lastUpdatedAt,
    this.scrollable = true,
    this.onClose,
  });

  final PartRequest? request;
  final DateTime? lastUpdatedAt;
  final bool scrollable;
  final VoidCallback? onClose;

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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Approval Detail',
                      style: TextStyle(
                        color: Color(0xFF16181D),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                    ),
                ],
              ),
              const SizedBox(height: 14),
              DetailCard(
                title: 'Selected: ${request!.idLabel}',
                body:
                    '${request!.partName} is waiting for approver action. Any status change must be reconfirmed by the approver before the app sends the update to /api/mobile/part-request/${request!.id}.',
              ),
              const SizedBox(height: 12),
              DetailCard(
                title: 'Request Info',
                body:
                    'Brand: ${request!.brand}\nModel: ${request!.model}\nMachine: ${request!.machine}\nPart Category: ${request!.category}\nCost: RM ${request!.cost.toStringAsFixed(2)}\nRequested By: ${request!.requestedBy}\nCreated At: ${request!.createdAt}',
              ),
              if (request!.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                DetailCard(title: 'Description', body: request!.description),
              ],
              const SizedBox(height: 12),
              DetailCard(
                title: 'Remark',
                body: request!.remark.isEmpty ? '-' : request!.remark,
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

class _EditableInputBlock extends StatelessWidget {
  const _EditableInputBlock({
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

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
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F9FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE3E6EF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE3E6EF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E2330)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

enum ApprovalStatus {
  newRequest(1, 'New', 'New'),
  pending(2, 'Pending', 'Pending'),
  collected(3, 'Collected', 'Collected'),
  returned(4, 'Returned', 'Returned'),
  used(5, 'Used', 'Used'),
  disposed(6, 'Disposed', 'Disposed');

  const ApprovalStatus(this.apiValue, this.label, this.shortLabel);

  final int apiValue;
  final String label;
  final String shortLabel;

  bool get isClosed => this == ApprovalStatus.disposed;

  static ApprovalStatus fromApiValue(dynamic rawStatus) {
    if (rawStatus is Map<String, dynamic>) {
      final nestedId = rawStatus['id'] ?? rawStatus['status'];
      if (nestedId != null) {
        return fromApiValue(nestedId);
      }

      final nestedName = rawStatus['name']?.toString().toLowerCase();
      if (nestedName != null) {
        return values.firstWhere(
          (status) =>
              status.shortLabel.toLowerCase() == nestedName ||
              status.label.toLowerCase() == nestedName,
          orElse: () => ApprovalStatus.newRequest,
        );
      }
    }

    final intValue = int.tryParse('$rawStatus');
    if (intValue != null) {
      return values.firstWhere(
        (status) => status.apiValue == intValue,
        orElse: () => ApprovalStatus.newRequest,
      );
    }

    final stringValue = '$rawStatus'.toLowerCase();
    return values.firstWhere(
      (status) =>
          status.shortLabel.toLowerCase() == stringValue ||
          status.label.toLowerCase() == stringValue,
      orElse: () => ApprovalStatus.newRequest,
    );
  }

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
      case ApprovalStatus.collected:
        return const StatusChipStyle(
          background: Color(0xFFF2F8EC),
          border: Color(0xFFD3E4BF),
          foreground: Color(0xFF5C7F2D),
        );
      case ApprovalStatus.used:
        return const StatusChipStyle(
          background: Color(0xFFEAF7F6),
          border: Color(0xFFC2E5E0),
          foreground: Color(0xFF23756B),
        );
      case ApprovalStatus.disposed:
        return const StatusChipStyle(
          background: Color(0xFFF3F0FF),
          border: Color(0xFFD8D0F8),
          foreground: Color(0xFF6B58B8),
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
    required this.brandId,
    required this.brand,
    required this.modelId,
    required this.model,
    required this.machineId,
    required this.machine,
    required this.categoryId,
    required this.category,
    required this.requestedBy,
    required this.cost,
    required this.createdAt,
    required this.description,
    required this.remark,
    required this.status,
  });

  final int id;
  final String partName;
  final int? brandId;
  final String brand;
  final int? modelId;
  final String model;
  final int? machineId;
  final String machine;
  final int? categoryId;
  final String category;
  final String requestedBy;
  final double cost;
  final String createdAt;
  final String description;
  final String remark;
  ApprovalStatus status;

  String get idLabel => 'PR-$id';

  DateTime get createdDate => DateTime.tryParse(createdAt) ?? DateTime(1970);

  bool get hasRequiredUpdateIds =>
      brandId != null &&
      modelId != null &&
      machineId != null &&
      categoryId != null;

  Map<String, dynamic> toUpdatePayload(ApprovalStatus nextStatus) {
    final payload = <String, dynamic>{
      'part_name': partName,
      'description': description,
      'remark': remark,
      'status': nextStatus.apiValue,
      'status_id': nextStatus.apiValue,
    };

    if (brandId != null) payload['brand_id'] = brandId;
    if (modelId != null) payload['brand_model_id'] = modelId;
    if (machineId != null) payload['machine_id'] = machineId;
    if (categoryId != null) payload['part_category_id'] = categoryId;

    return payload;
  }

  factory PartRequest.fromJson(Map<String, dynamic> json) {
    final id = _readInt(json['id']);
    if (id == null) {
      throw const FormatException('Missing part request id.');
    }

    final createdValue = _readString(json['created_at']) ?? '';
    final createdAt = createdValue.contains(' ')
        ? createdValue.split(' ').first
        : createdValue;

    return PartRequest(
      id: id,
      partName:
          _readString(json['part_name']) ??
          _readString(json['part_name_label']) ??
          _readString(json['name']) ??
          _readNestedString(json['part_category'], 'name') ??
          'Unnamed part request',
      brandId:
          _readInt(json['brand_id']) ?? _readNestedInt(json['brand'], 'id'),
      brand:
          _readNestedString(json['brand'], 'name') ??
          _readString(json['brand_name']) ??
          '-',
      modelId:
          _readInt(json['brand_model_id']) ??
          _readNestedInt(json['brand_model'], 'id'),
      model:
          _readNestedString(json['brand_model'], 'name') ??
          _readString(json['brand_model_name']) ??
          '-',
      machineId:
          _readInt(json['machine_id']) ?? _readNestedInt(json['machine'], 'id'),
      machine:
          _readNestedString(json['machine'], 'name') ??
          _readString(json['machine_name']) ??
          '-',
      categoryId:
          _readInt(json['part_category_id']) ??
          _readNestedInt(json['part_category'], 'id'),
      category:
          _readNestedString(json['part_category'], 'name') ??
          _readString(json['part_category_name']) ??
          '-',
      requestedBy:
          _readNestedString(json['user'], 'name') ??
          _readNestedString(json['created_by'], 'name') ??
          _readString(json['user_name']) ??
          '-',
      cost: _readDouble(json['cost']) ?? 0,
      createdAt: createdAt.isEmpty ? '-' : createdAt,
      description: _readString(json['description']) ?? '',
      remark: _readString(json['remark']) ?? '',
      status: ApprovalStatus.fromApiValue(
        json['status'] ?? json['status_id'] ?? json['approval_status'],
      ),
    );
  }

  PartRequest mergeWithFallback(PartRequest fallback) {
    return PartRequest(
      id: id,
      partName: partName == 'Unnamed part request'
          ? fallback.partName
          : partName,
      brandId: brandId ?? fallback.brandId,
      brand: brand == '-' ? fallback.brand : brand,
      modelId: modelId ?? fallback.modelId,
      model: model == '-' ? fallback.model : model,
      machineId: machineId ?? fallback.machineId,
      machine: machine == '-' ? fallback.machine : machine,
      categoryId: categoryId ?? fallback.categoryId,
      category: category == '-' ? fallback.category : category,
      requestedBy: requestedBy == '-' ? fallback.requestedBy : requestedBy,
      cost: cost == 0 ? fallback.cost : cost,
      createdAt: createdAt == '-' ? fallback.createdAt : createdAt,
      description: description.isEmpty ? fallback.description : description,
      remark: remark.isEmpty ? fallback.remark : remark,
      status: status,
    );
  }
}

class _RequestDateGroup {
  const _RequestDateGroup({required this.date, required this.requests});

  final DateTime date;
  final List<PartRequest> requests;
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double? _readDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

String? _readString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.trim();
  if (value is num || value is bool) return '$value';
  return null;
}

String? _readNestedString(dynamic value, String key) {
  if (value is Map<String, dynamic>) {
    return _readString(value[key]);
  }
  if (value is Map) {
    return _readString(value[key]);
  }
  return null;
}

int? _readNestedInt(dynamic value, String key) {
  if (value is Map<String, dynamic>) {
    return _readInt(value[key]);
  }
  if (value is Map) {
    return _readInt(value[key]);
  }
  return null;
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour > 12
      ? dateTime.hour - 12
      : (dateTime.hour == 0 ? 12 : dateTime.hour);
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

List<_RequestDateGroup> _groupRequestsByDate(List<PartRequest> requests) {
  final grouped = <_RequestDateGroup>[];

  for (final request in requests) {
    final date = request.createdDate;
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (grouped.isNotEmpty && _isSameDay(grouped.last.date, normalizedDate)) {
      grouped.last.requests.add(request);
      continue;
    }

    grouped.add(_RequestDateGroup(date: normalizedDate, requests: [request]));
  }

  return grouped;
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _formatRequestSectionDate(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final weekday = weekdays[dateTime.weekday - 1];
  final month = months[dateTime.month - 1];
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$weekday, $day $month ${dateTime.year}';
}

String _friendlyLoginFailure(Object error) {
  if (kIsWeb) {
    return 'When this app runs in a browser, the WOD backend may reject POST /api/mobile/login with CSRF protection. Run the app as a desktop build or allow the browser origin on the backend.';
  }

  return 'Please check the API response and your credentials. ($error)';
}
