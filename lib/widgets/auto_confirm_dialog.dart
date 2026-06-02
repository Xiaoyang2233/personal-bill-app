import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/auto_bookkeeping_provider.dart';
import '../utils/currency_utils.dart';

class AutoConfirmDialog extends StatefulWidget {
  final ParsedNotification notification;
  final int currentIndex;
  final int totalCount;
  final Function(String category, String note) onConfirm;
  final VoidCallback onModify;
  final VoidCallback onCancel;

  const AutoConfirmDialog({
    super.key,
    required this.notification,
    this.currentIndex = 1,
    this.totalCount = 1,
    required this.onConfirm,
    required this.onModify,
    required this.onCancel,
  });

  @override
  State<AutoConfirmDialog> createState() => _AutoConfirmDialogState();
}

class _AutoConfirmDialogState extends State<AutoConfirmDialog> {
  late String _selectedCategory;
  final _noteController = TextEditingController();
  Timer? _autoDismissTimer;
  int _countdown = 10;

  static const _categories = [
    '餐饮', '交通', '购物', '娱乐', '生活费', '其他',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.notification.suggestedCategory ?? '其他';
    _startCountdown();
  }

  void _startCountdown() {
    _autoDismissTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        widget.onCancel();
        Navigator.of(context).pop();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = widget.notification.type == 'expense';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            color: isExpense ? Colors.red : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(isExpense ? '检测到支出' : '检测到收入'),
          const Spacer(),
          if (widget.totalCount > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${widget.currentIndex}/${widget.totalCount}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: _countdown / 10,
              strokeWidth: 2.5,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('来源', widget.notification.sourceName),
          _buildInfoRow('金额', formatCurrency(widget.notification.amount)),
          if (widget.notification.merchant != null)
            _buildInfoRow('商户', widget.notification.merchant!),
          const SizedBox(height: 12),
          const Text('分类', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 4),
          DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedCategory = v);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: '备注（可选）',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _autoDismissTimer?.cancel();
            widget.onCancel();
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            _autoDismissTimer?.cancel();
            widget.onModify();
            Navigator.of(context).pop();
          },
          child: const Text('修改'),
        ),
        FilledButton(
          onPressed: () {
            _autoDismissTimer?.cancel();
            widget.onConfirm(_selectedCategory, _noteController.text.trim());
            Navigator.of(context).pop();
          },
          child: const Text('确认'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
