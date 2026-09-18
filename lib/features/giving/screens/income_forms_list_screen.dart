import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/sunday_income_form.dart';
import '../../../repositories/repository_providers.dart';
import '../zmw_denominations.dart';
import '../../../core/utils/currency_format.dart';
import 'income_form_detail_screen.dart';

class IncomeFormsListScreen extends ConsumerWidget {
  const IncomeFormsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formsAsync = ref.watch(incomeFormsProvider);
    final valuesByKey = {for (final d in zmwDenominations) d.key: d.value};

    return Scaffold(
      appBar: AppBar(title: const Text('Sunday Income Forms')),
      body: formsAsync.when(
        data: (forms) {
          if (forms.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No Sunday income forms yet.\nSaved forms will appear here.',
            );
          }
          return ListView.builder(
            itemCount: forms.length,
            itemBuilder: (context, index) {
              final form = forms[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
                  title: Text('${formatDate(form.date)} — ${form.service.label}'),
                  subtitle: Text(
                      'Grand Total: ${formatZmw(form.grandTotal(valuesByKey))}'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => IncomeFormDetailScreen(form: form)),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
