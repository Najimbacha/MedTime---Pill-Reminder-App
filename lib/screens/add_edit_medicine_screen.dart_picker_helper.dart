Future<TimeOfDay?> _showModernTimePicker(
  BuildContext context,
  TimeOfDay initialTime,
) async {
  TimeOfDay? pickedTime;
  final now = DateTime.now();
  // Create a DateTime with the initial time
  DateTime tempDate = DateTime(
    now.year,
    now.month,
    now.day,
    initialTime.hour,
    initialTime.minute,
  );

  // iOS style bottom sheet picker
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        height: 320,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // 1. Handle & Header
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    'Select Time',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      pickedTime = TimeOfDay.fromDateTime(tempDate);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 2. The Picker
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: isDark ? Brightness.dark : Brightness.light,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontSize: 22,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: tempDate,
                  use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                  onDateTimeChanged: (DateTime newDate) {
                    tempDate = newDate;
                    HapticHelper.selection();
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );

  return pickedTime;
}
