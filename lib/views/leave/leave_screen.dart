import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ess_mobile/widgets/scaffold.dart';
import 'package:ess_mobile/widgets/drawer.dart';
import 'package:ess_mobile/widgets/actionbutton.dart';
import 'package:ess_mobile/providers/auth_provider.dart';
import 'package:ess_mobile/utils/api_response.dart';
import 'package:ess_mobile/utils/globals.dart' as globals;
import 'package:ess_mobile/utils/localizations.dart';
import 'package:ess_mobile/utils/routes.dart';
import 'package:ess_mobile/models/leave_model.dart';
import 'package:ess_mobile/services/leave_service.dart';
import 'package:ess_mobile/views/leave/calendar_screen.dart';
import 'package:ess_mobile/views/leave/history_screen.dart';
import 'package:ess_mobile/views/leave/subordinate_screen.dart';

class LeaveScreen extends StatefulWidget {
  @override
  _LeaveScreenState createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final LeaveService _leaveService = LeaveService();
  LeaveInfoModel _leaveInfo = LeaveInfoModel();
  dynamic _filterReq;
  int _totalPending = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (context.read<AuthProvider>().status != AppStatus.Authenticated) {
        context.read<AuthProvider>().signOut();

        Navigator.pop(context);
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.login,
          ModalRoute.withName(Routes.login),
        );
      }
    });

    Map<String, dynamic> getValue = {
      'Start': globals.today.subtract(Duration(days: 30)).toIso8601String(),
      'Finish': globals.today.add(Duration(days: 30)).toIso8601String(),
    };

    _filterReq = globals.getFilterRequest(params: getValue);

    _leaveService.leaveInfo(_filterReq).then((v) {
      if (v.status == ApiStatus.COMPLETED) {
        if (v.data.data != null) {
          if (this.mounted) {
            setState(() {
              _leaveInfo = v.data.data;
              _totalPending = _leaveInfo.totalPending ?? 0;
            });
          } 
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppScaffold(
        navBar: NavBar(
          title: Text(AppLocalizations.of(context).translate('Leave')),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.date_range),
                text: AppLocalizations.of(context).translate('Calendar'),
              ),
              Tab(
                icon: Icon(Icons.history),
                text: AppLocalizations.of(context).translate('History'),
              ),
              Tab(
                icon: Icon(Icons.supervisor_account),
                text: AppLocalizations.of(context).translate('Subordinate'),
              ),
            ],
          ),
        ),
        main: TabBarView(
          children: [
            CalendarScreen(_filterReq),
            HistoryScreen(_filterReq),
            SubordinateScreen(_filterReq),
          ],
        ),
        drawer: AppDrawer(tokenUrl: globals.appAuth.data),
        actionButton: AppActionButton(
          create: _totalPending > 0 ? null : (){
            Navigator.pushNamed(
              context,
              Routes.leaveRequest,
            ).then((val) {
              Navigator.pushReplacementNamed(context, Routes.leave);
            });
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
