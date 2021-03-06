import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ess_mobile/widgets/error.dart';
import 'package:ess_mobile/widgets/loading.dart';
import 'package:ess_mobile/widgets/snackbar.dart';
import 'package:ess_mobile/widgets/datatable.dart';
import 'package:ess_mobile/providers/auth_provider.dart';
import 'package:ess_mobile/utils/globals.dart' as globals;
import 'package:ess_mobile/utils/localizations.dart';
import 'package:ess_mobile/utils/routes.dart';
import 'package:ess_mobile/utils/api_response.dart';
import 'package:ess_mobile/services/survey_service.dart';
import 'package:ess_mobile/models/survey_model.dart';

class SurveyListScreen extends StatefulWidget {
  final dynamic filterRequest;

  SurveyListScreen(this.filterRequest);

  @override
  _SurveyListScreenState createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  final SurveyService _surveyService = SurveyService();

  late Future<ApiResponse<dynamic>> _surveys;
  late Future<ApiResponse<dynamic>> _temporary;

  Map<String, dynamic> getValue = {
    'Start': globals.today.subtract(Duration(
      days: 7,
      hours: globals.today.hour, 
      minutes: globals.today.minute, 
      seconds: globals.today.second, 
      milliseconds: globals.today.millisecond, 
      microseconds: globals.today.microsecond
    )).toIso8601String(),
    'Finish': globals.today.toIso8601String(),
  };

  bool _loading = false;

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

    setState(() {
      _surveys = _surveyService
          .surveys(globals.getFilterRequest(params: getValue));
      _temporary = _surveyService.getAbsenceTemporary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: _container(context),
      /*child: Padding(
        padding: EdgeInsets.all(5.0),
      )*/
    );
  }

  Widget _container(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          FutureBuilder<ApiResponse<dynamic>>(
            future: _surveys,
            builder: (context, snapshot) {
              List<DataRow> _dataRows = <DataRow>[];

              if (snapshot.hasError) {
                AppSnackBar.danger(context, snapshot.error.toString());
              }

              if (snapshot.hasData) {
                var _response = snapshot.data?.data;

                switch (snapshot.data!.status) {
                  case ApiStatus.LOADING:
                    return AppLoading(
                      loadingMessage: snapshot.data!.message,
                    );

                  case ApiStatus.COMPLETED:
                    if (_response.data.length > 0) {

                      var indexData = 0;
                      _response.data.reversed.forEach((v) {
                        _dataRows.add(DataRow(
                          cells: _dataCells(v),
                          color: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                            // Even rows will have a grey color.
                            if (indexData.isEven) {
                              return Colors.grey.withOpacity(0.3);
                            }
                            return Colors.white;
                            // Use default value for other states and odd rows.
                          })
                        ));
                        indexData++;
                      });
                    }

                    if (_response.message != null) {
                      return AppError(
                        errorMessage: _response.message,
                        onRetryPressed: () => setState(() {
                          _surveys = _surveyService
                              .surveys(globals.getFilterRequest());
                        }),
                      );
                    }
                    break;
                  case ApiStatus.ERROR:
                    return AppError(
                      errorMessage: snapshot.data!.message,
                      onRetryPressed: () => setState(() {
                        _surveys = _surveyService
                            .surveys(globals.getFilterRequest());
                      }),
                    );
                }
              }

              return (snapshot.connectionState == ConnectionState.done)
                  ? AppDataTable(
                      columns: <DataColumn>[
                        DataColumn(
                          label: Text(''),
                        ),
                        DataColumn(
                          label: Text(
                            AppLocalizations.of(context).translate('Title'),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            AppLocalizations.of(context).translate('Schedule'),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            AppLocalizations.of(context).translate('Required'),
                          ),
                        )
                      ],
                      columnWidths: {
                        0: FixedColumnWidth(55),
                        1: FlexColumnWidth(),
                        2: FixedColumnWidth(95),
                        3: FixedColumnWidth(60)
                      },
                      rows: _dataRows,
                    )
                  : AppLoading();
            },
          ),
          FutureBuilder(
            future: Future.wait([_surveys, _temporary]),
            builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
              if (snapshot.hasData) {
                var respSurveys = snapshot.data![0].data;
                var respTemps = snapshot.data![1].data;
                int countSurvey = 0;
                
                respSurveys.data.reversed.forEach((v) {
                  if(v.alreadyFilled == false && v.isRequired == true){
                    countSurvey++;
                  }
                });
                
                if(respTemps.data.isNotEmpty && countSurvey == 0) {
                  return ElevatedButton.icon(
                    onPressed: (){
                      updateMobileAttendance();
                    }, 
                    label: Text('Update Mobile Attendance'),
                    icon: Icon(Icons.update),
                    style: ElevatedButton.styleFrom(primary: Colors.blue)
                  );
                }
              }
              return Container();
            }
          )
        ],
      )
    );
  }


  @override
  void dispose() {
    super.dispose();
  }

  List<DataCell> _dataCells(SurveyModel item) {
    /*item.project ??= '';
    item.absenceCode ??= '';
    item.absenceCodeDescription ??= '';*/

    List _recurrent = ['None', 'Once', 'Daily', 'Weekly', 'Monthly', 'Yearly'];
    
    DateTime _scheduledDateStart = DateFormat('yyyy-MM-ddTHH:mm:ss')
        .parse(item.schedule!.start!, false)
        .toLocal();
    DateTime _scheduledDateFinish = DateFormat('yyyy-MM-ddTHH:mm:ss')
        .parse(item.schedule!.finish!, false)
        .toLocal();
    String _scheduledDate = DateFormat('dd/MM/yyyy').format(_scheduledDateStart) +
        ' - ' +
        DateFormat('dd/MM/yyyy').format(_scheduledDateFinish);
    
    TextStyle? _textStyle = TextStyle(
      color: Theme.of(context).buttonTheme.colorScheme?.onSurface,
    );

    return <DataCell>[
      DataCell(InkWell(
        child: CircleAvatar(
          radius: 14,
          backgroundColor:
              Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
          child: item.alreadyFilled! ? Icon(Icons.stop, color: Colors.black) : Icon(Icons.play_arrow, color: Colors.green)
        ),
        onTap: (item.alreadyFilled!)
          ? null
          : () {
          Navigator.pushNamed(
            context,
            Routes.appbrowser,
            arguments: {
              'name': item.title.toString(),
              'link': item.surveyUrl.toString(),
            },
          );
        },
      )),
      DataCell(Text(item.title.toString(), style: _textStyle)),
      DataCell(Text(_scheduledDate.toString(), style: _textStyle)),
      //DataCell(Text(_recurrent[item.recurrent!], style: _textStyle)),
      DataCell(CircleAvatar(
          radius: 14,
          backgroundColor:
              Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
          child: item.isRequired! ? Icon(Icons.priority_high, color: Colors.red) : Icon(Icons.check_box_outline_blank, color: Colors.black)
        )
      ),
    ];
  }

  void updateMobileAttendance()async{
    
    setState(() {
      _loading = true;
    });
    _surveyService.updateMobileAttendance().then((res) {
      setState(() {
        _loading = false;
      });
      if (res.status == ApiStatus.ERROR) {
        AppSnackBar.danger(context, res.message);
      }
      if (res.status == ApiStatus.COMPLETED){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              action: SnackBarAction(label: 'OK',onPressed: () {}),
              // content:  Text('${upl.data['Message'].toString()}'),
              content: Text('Update successfully!'),
              duration: const Duration(milliseconds: 5000),
              behavior: SnackBarBehavior.floating
            )
        );
      }
    }).onError((error, stackTrace) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              action: SnackBarAction(label: 'Error',onPressed: () {}),
              // content:  Text('${upl.data['Message'].toString()}'),
              content: Text(error.toString()),
              duration: const Duration(milliseconds: 5000),
              behavior: SnackBarBehavior.floating
            )
        );
    });
    // _surveyService.complaintSave(fileDoc, data, reason)

  }

  Future<void> _refreshData() async {
    await Future.delayed(Duration(seconds: 4));
    setState(() {
      _surveys = _surveyService
          .surveys(globals.getFilterRequest(params: getValue));
    });
  }
}
