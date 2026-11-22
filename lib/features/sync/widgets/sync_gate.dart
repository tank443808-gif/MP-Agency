import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/widgets/app_logo.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/sync/services/data_sync.dart';

/// 로그인 후 첫 데이터를 받을 때까지 로딩 화면을 보여주고, 다 받으면 [builder]를 그림
class SyncGate extends StatefulWidget {
  const SyncGate({super.key, required this.user, required this.builder});

  final AppUser user;
  final WidgetBuilder builder;

  @override
  State<SyncGate> createState() => _SyncGateState();
}

class _SyncGateState extends State<SyncGate> {
  late final Future<void> _ready = DataSync.instance.start(widget.user);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done) {
          return widget.builder(context);
        }
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 30),
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: AppColors.orange),
                const SizedBox(height: 14),
                Text(
                  '오늘의 다먹음을 불러오는 중…',
                  style: AppFonts.display(size: 14, color: AppColors.subText),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
