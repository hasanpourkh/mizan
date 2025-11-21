// lib/src/widgets/charts/chart_widgets.dart
// پیاده‌سازی سبک و مستقل نمودارها (بدون وابستگی به fl_chart)
// - این فایل یک جایگزین موقت/ایمن است تا اپ روی همهٔ پلتفرم‌ها بیلد شود.
// - ویجت‌های ارائه‌شده:
//   - dailySalesLineChart(List<Map>)  -> نمودار خطی ساده
//   - weeklySalesBarChart(List<Map>) -> نمودار ستونی ساده
//   - profitSharesPieChart(List<Map>) -> نمودار دایره‌ای ساده
// - ورودی‌ها همان ساختارهایی هستند که ReportRepository تولید می‌کند.
// - اگر خواستی بعداً fl_chart اضافه کنیم تا ظاهر حرفه‌ای‌تر شود؛ فعلاً این فایل قابل اجرا و مستقل است.
// - کامنت‌های فارسی مختصر در هر بخش برای راهنمایی قرار گرفته است.

import 'package:flutter/material.dart';
import 'dart:math';

/// Line chart ساده برای نمایش فروش روزانه
/// dailyData: [{'day': 'YYYY-MM-DD', 'total': 123.45}, ...] (به ترتیب صعودی)
Widget dailySalesLineChart(List<Map<String, dynamic>> dailyData,
    {Color lineColor = Colors.blue}) {
  if (dailyData.isEmpty) {
    return const Center(child: Text('داده‌ای برای نمایش وجود ندارد'));
  }

  final totals = dailyData
      .map((e) => (e['total'] is num)
          ? (e['total'] as num).toDouble()
          : double.tryParse(e['total']?.toString() ?? '0') ?? 0.0)
      .toList();

  return _SimpleLineChart(
    labels: dailyData.map((e) => e['day']?.toString() ?? '').toList(),
    values: totals,
    lineColor: lineColor,
    height: 220,
  );
}

/// Bar chart ساده برای نمایش فروش هفتگی
/// weeklyData: [{'week': 'YYYY-WW', 'total': 123.45}, ...] (صعودی)
Widget weeklySalesBarChart(List<Map<String, dynamic>> weeklyData,
    {Color barColor = Colors.teal}) {
  if (weeklyData.isEmpty) {
    return const Center(child: Text('داده‌ای برای نمایش وجود ندارد'));
  }

  final totals = weeklyData
      .map((e) => (e['total'] is num)
          ? (e['total'] as num).toDouble()
          : double.tryParse(e['total']?.toString() ?? '0') ?? 0.0)
      .toList();
  final labels = weeklyData.map((e) => e['week']?.toString() ?? '').toList();

  return _SimpleBarChart(
      labels: labels, values: totals, barColor: barColor, height: 220);
}

/// Pie chart ساده برای توزیع مبلغ در بین سهامداران
/// shares: [{'display_name': 'علی', 'amount': 123.0}, ...]
Widget profitSharesPieChart(List<Map<String, dynamic>> shares,
    {double height = 240}) {
  if (shares.isEmpty) {
    return const Center(child: Text('داده‌ای برای نمایش وجود ندارد'));
  }

  final amounts = shares
      .map((s) => (s['amount'] is num)
          ? (s['amount'] as num).toDouble()
          : double.tryParse(s['amount']?.toString() ?? '0') ?? 0.0)
      .toList();
  final labels =
      shares.map((s) => s['display_name']?.toString() ?? '').toList();

  return _SimplePieChart(labels: labels, values: amounts, height: height);
}

/* ============================
   پیاده‌سازی داخلی سادهٔ نمودارها
   - هدف: مستقل، بدون dependency خارجی، خوانا و قابل توسعه
   - استفاده از CustomPainter برای رسم خطوط / دایره / ستون
   ============================ */

class _SimpleLineChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color lineColor;
  final double height;

  const _SimpleLineChart(
      {required this.labels,
      required this.values,
      this.lineColor = Colors.blue,
      this.height = 200});

  @override
  Widget build(BuildContext context) {
    final maxVal = values.isEmpty ? 1.0 : values.reduce(max);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: height,
        child: Column(children: [
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(
                  values: values, lineColor: lineColor, maxValue: maxVal),
            ),
          ),
          const SizedBox(height: 6),
          // برچسب‌های پایین به شکل افقی (قابل اسکرول اگر زیاد باشند)
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: labels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final txt = labels[idx];
                return Text(txt, style: const TextStyle(fontSize: 11));
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final double maxValue;
  _LineChartPainter(
      {required this.values, required this.lineColor, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = Colors.grey.withOpacity(0.18)
      ..style = PaintingStyle.stroke;
    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final paintArea = Paint()
      ..color = lineColor.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    final paintDot = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    // grid horizontal
    const lines = 4;
    for (int i = 0; i <= lines; i++) {
      final y = size.height * i / lines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    if (values.isEmpty) return;

    final stepX =
        size.width / (values.length - 1 == 0 ? 1 : (values.length - 1));
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = stepX * i;
      final v = values[i];
      final ny = (maxValue <= 0)
          ? size.height
          : size.height - (v / maxValue * size.height);
      points.add(Offset(x, ny));
    }

    // draw area
    final areaPath = Path();
    areaPath.moveTo(points.first.dx, size.height);
    for (final p in points) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.close();
    canvas.drawPath(areaPath, paintArea);

    // draw line
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paintLine);

    // dots
    for (final p in points) {
      canvas.drawCircle(p, 3.4, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SimpleBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color barColor;
  final double height;

  const _SimpleBarChart(
      {required this.labels,
      required this.values,
      this.barColor = Colors.teal,
      this.height = 220});

  @override
  Widget build(BuildContext context) {
    final maxVal = values.isEmpty ? 1.0 : values.reduce(max);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: height,
        child: Column(children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (i) {
                final v = values[i];
                final hFactor = (maxVal <= 0) ? 0.0 : (v / maxVal);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // مقدار بالای هر ستون
                        Text(v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 6),
                        FractionallySizedBox(
                          heightFactor: hFactor.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: labels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) =>
                  Text(labels[idx], style: const TextStyle(fontSize: 11)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SimplePieChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final double height;

  const _SimplePieChart(
      {required this.labels, required this.values, this.height = 220});

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0.0, (p, e) => p + e.abs());
    return SizedBox(
      height: height,
      child: Column(children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _PiePainter(
                values: values, colors: _generateColors(values.length)),
          ),
        ),
        const SizedBox(height: 8),
        // legend
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 80),
          child: SingleChildScrollView(
            child: Column(
              children: List.generate(values.length, (i) {
                final name = labels.length > i ? labels[i] : '—';
                final v = values[i];
                final perc = total == 0 ? 0.0 : (v.abs() / total) * 100.0;
                return Row(
                  children: [
                    Container(
                        width: 12,
                        height: 12,
                        color: _generateColors(values.length)[i]),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            Text(name, style: const TextStyle(fontSize: 12))),
                    Text('${perc.toStringAsFixed(1)} %',
                        style: const TextStyle(fontSize: 12)),
                  ],
                );
              }),
            ),
          ),
        ),
      ]),
    );
  }

  // تولید رنگ‌های متفاوت برای بخش‌ها
  static List<Color> _generateColors(int n) {
    final rnd = Random(42);
    return List.generate(
        n,
        (_) => Color.fromARGB(255, rnd.nextInt(200) + 20, rnd.nextInt(200) + 20,
            rnd.nextInt(200) + 20));
  }
}

class _PiePainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _PiePainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0.0, (p, e) => p + e.abs());
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.4;
    double startAngle = -pi / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    if (total <= 0.000001) {
      // رسم دایره خاکستری وقتی داده مفیدی نیست
      paint.color = Colors.grey.shade300;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    for (int i = 0; i < values.length; i++) {
      final v = values[i].abs();
      final sweep = (v / total) * 2 * pi;
      paint.color = colors.length > i
          ? colors[i]
          : Colors.primaries[i % Colors.primaries.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, sweep, true, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
