import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_strings.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    final show = connectivity.shouldShowBanner;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: show
          ? Container(
              width: double.infinity,
              color: AppColors.behindSoft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SafeArea(
                bottom: false,
                top: false,
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 16,
                      color: AppColors.behind,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppStrings.offlineBannerText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.behind,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    InkWell(
                      onTap: () => connectivity.dismissBanner(),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.behind,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
