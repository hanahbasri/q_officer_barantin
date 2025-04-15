import 'package:intl/intl.dart';

String formatTanggal(dynamic date) {
  // If the input is a String, try to parse it into a DateTime object
  if (date is String) {
    try {
      date = DateTime.parse(date);  // Try parsing the string into a DateTime object
    } catch (e) {
      // If the string is not a valid date format, return an empty string or handle the error as needed
      return "Invalid Date Format";
    }
  }

  // If the input is a DateTime object, format it
  if (date is DateTime) {
    return DateFormat("EEEE, dd MMMM yyyy HH:mm", "id_ID").format(date);
  } else {
    // If the input is neither a String nor DateTime, return an error or a default value
    return "Invalid Input";
  }
}