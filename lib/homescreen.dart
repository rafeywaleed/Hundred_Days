import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hundred_days/add_tasks.dart';
import 'package:hundred_days/pages/record_view.dart';
import 'package:hundred_days/pages/settings.dart';
import 'package:hundred_days/pages/splash_screen.dart';
import 'package:hundred_days/utils/dialog_box.dart';
import 'package:hundred_days/utils/loader.dart';
import 'package:iconly/iconly.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workmanager/src/workmanager.dart';
import 'package:workmanager/workmanager.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();

  // Future<void> uploadTasksIfOffline() async {
  //   final connectivityResult = await Connectivity().checkConnectivity();
  //   if (connectivityResult == ConnectivityResult.none) {
  //     await saveTasksToSharedPreferences([]);
  //   } else {
  //     await saveProgress();
  //   }
  // }
}

// Future<void> uploadTasksIfOffline() async {
//   final connectivityResult = await Connectivity().checkConnectivity();
//   if (connectivityResult == ConnectivityResult.none) {
//     await saveTasksToSharedPreferences([]);
//   } else {
//     await saveProgress();
//   }
// }

// void callbackDispatcher() {
//   Workmanager().executeTask((task) async {
//     final connectivityResult = await Connectivity().checkConnectivity();
//     if (connectivityResult == ConnectivityResult.none) {
//       await saveTasksToSharedPreferences([]);
//     } else {
//       await saveProgress();
//     }
//     return Future.value(true);
//   } as BackgroundTaskHandler);
// }

// Future<void> saveTasksToSharedPreferences(
//     List<Map<String, dynamic>> tasks) async {
//   SharedPreferences prefs = await SharedPreferences.getInstance();
//   List<String> taskList = tasks.map((task) => jsonEncode(task)).toList();
//   await prefs.setStringList('defaultTasks', taskList);
// }

// Future<void> saveProgress() async {
//   final firestore = FirebaseFirestore.instance;
//   final String? userEmail = FirebaseAuth.instance.currentUser?.email;

//   if (userEmail != null) {
//     String today = DateFormat('dd-MM-yyyy').format(DateTime.now());
//     DocumentReference taskRecordDoc = firestore
//         .collection('taskRecord')
//         .doc(userEmail)
//         .collection('records')
//         .doc(today);

//     List<Map<String, dynamic>> defaultTasks = [
//       {'task': 'Task 1', 'completed': false},
//       {'task': 'Task 2', 'completed': true},
//     ];

//     List<Map<String, dynamic>> taskProgress = defaultTasks
//         .map((task) => {
//               'task': task['task'],
//               'status': task['completed'] ? 'completed' : 'incomplete'
//             })
//         .toList();

//     int totalTasks = taskProgress.length;
//     int completedTasks =
//         taskProgress.where((task) => task['status'] == 'completed').length;
//     double overallCompletion =
//         totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;

//     await taskRecordDoc.set({
//       'tasks': taskProgress,
//       'overallCompletion': '$completedTasks/$totalTasks',
//       'date': today,
//     });
//   }
// }

// void scheduleTaskAtTime(int targetHour, int targetMinute) {
//   DateTime now = DateTime.now();

//   // Calculate how many hours and minutes are left until the target time
//   Duration delay;
//   if (now.hour < targetHour ||
//       (now.hour == targetHour && now.minute < targetMinute)) {
//     delay = Duration(
//       hours: targetHour - now.hour,
//       minutes: targetMinute - now.minute,
//       seconds: 00 - now.second,
//     );
//   } else {
//     // If the current time is past the target time, schedule it for the next day
//     delay = Duration(
//       hours: (24 - now.hour) + targetHour,
//       minutes: targetMinute - now.minute,
//       seconds: 00 - now.second,
//     );
//   }

//   // Register the periodic task
//   Workmanager().registerPeriodicTask(
//     'dailyTaskUpload',
//     'uploadTasksAtFixedTime',
//     frequency: Duration(hours: 24), // Repeat every 24 hours
//     initialDelay: delay, // Delay until the specified time
//   );

//   // Add a BroadcastReceiver to listen for network connectivity changes
//   Connectivity().onConnectivityChanged.listen((connectivityResult) {
//     if (connectivityResult != ConnectivityResult.none) {
//       // Device is online, trigger the task
//       uploadTasksIfOffline();
//     }
//   });
// }

// void scheduleTaskAtMidnight() {
//   Workmanager().registerPeriodicTask(
//     'dailyTaskUpload',
//     'uploadTasksAtMidnight',
//     frequency: Duration(hours: 24),
//     initialDelay: Duration(
//       hours: 19 - DateTime.now().hour,
//       minutes: 59 - DateTime.now().minute,
//       seconds: 00 - DateTime.now().second,
//     ),
//   );

//   // Add a BroadcastReceiver to listen for network connectivity changes
//   Connectivity().onConnectivityChanged.listen((connectivityResult) {
//     if (connectivityResult != ConnectivityResult.none) {
//       // Device is online, trigger the task
//       uploadTasksIfOffline();
//     }
//   });
// }

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> defaultTasks = [];
  List<Map<String, dynamic>> additionalTasks = [];
  String? userEmail;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  int _selectedIndex = 0;
  NavigationRailLabelType labelType = NavigationRailLabelType.all;

  @override
  void initState() {
    super.initState();
    loadUserEmail();
    loadDailyTasks();
    fetchAdditionalTasks();
    printSt();
    resetTaskAnyway();
    checkAndUpdateTasks();
    startNetworkListener();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> checkAndUpdateTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

    String? storedDate = prefs.getString('tDate');
    print("inside check and Update");

    if (storedDate == null || storedDate != currentDate) {
      print("entered if condition");
      await saveProgress();
      print("save progress complete");
      await resetTasks();
      print("task's reset");
      await prefs.setString('tDate', currentDate);
      print(prefs.getString('tDate'));
    } else {
      print("date matched");
      loadDailyTasks();
    }
  }

  Future<void> resetTaskAnyway() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? storedData = prefs.getString('tDate');
    print('Currently stored date: $storedData'); // Debugging output

    String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

    if (storedData == null || storedData != todayDate) {
      await resetTasks();
      await prefs.setString('tDate', todayDate);
      print('Saved new date: $todayDate'); // Debugging output
    }
  }

  // Future<void> resetTasks() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   await prefs.setStringList('defaultTasks', []);
  //   print("Tasks delte kar diya saab");
  // }

  Future<void> resetTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? taskJsonList = prefs.getStringList('defaultTasks');

    if (taskJsonList != null) {
      List<Map<String, dynamic>> tasks = taskJsonList.map((taskJson) {
        return Map<String, dynamic>.from(jsonDecode(taskJson));
      }).toList();

      List<Map<String, dynamic>> updatedTasks = tasks.map((task) {
        return {
          'task': task['task'], // Use 'task' instead of 'name'
          'completed': false,
        };
      }).toList();

      // Convert the updated tasks back to JSON and save them
      List<String> updatedTaskJsonList = updatedTasks.map((task) {
        return jsonEncode(task);
      }).toList();

      await prefs.setStringList('defaultTasks', updatedTaskJsonList);
      print("All tasks marked as incomplete.");

      // Update the defaultTasks in the state
      setState(() {
        defaultTasks = updatedTasks;
      });
    } else {
      print("No tasks found to reset.");
    }
  }

  Future<void> saveNormalProgress() async {
    String? userId = auth.currentUser?.uid;
    String? userEmail = auth.currentUser?.email;
    if (userId != null && userEmail != null) {
      String today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      DocumentReference taskRecordDoc = firestore
          .collection('taskRecord')
          .doc(userEmail)
          .collection('records')
          .doc(today);

      List<Map<String, dynamic>> taskProgress = defaultTasks
          .map((task) => {
                'task': task['task'],
                'status': task['completed'] ? 'completed' : 'incomplete'
              })
          .toList();

      int totalTasks = taskProgress.length;
      int completedTasks =
          taskProgress.where((task) => task['status'] == 'completed').length;
      double overallCompletion =
          totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;

      await taskRecordDoc.set({
        'tasks': taskProgress,
        'overallCompletion': '$completedTasks/$totalTasks',
        'date': today,
      });
    }
  }

  Future<void> saveProgress() async {
    String? userId = auth.currentUser?.uid;
    String? userEmail = auth.currentUser?.email;
    print("inside saveProgress");
    if (userId != null && userEmail != null) {
      String today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      List<Map<String, dynamic>> taskProgress = defaultTasks
          .map((task) => {
                'task': task['task'],
                'status': task['completed'] ? 'completed' : 'incomplete'
              })
          .toList();

      int totalTasks = taskProgress.length;
      int completedTasks =
          taskProgress.where((task) => task['status'] == 'completed').length;

      // Check internet connectivity
      ConnectivityResult connectivityResult =
          (await Connectivity().checkConnectivity()) as ConnectivityResult;

      if (connectivityResult == ConnectivityResult.none) {
        // Device is offline, save data to be uploaded later
        await saveToBeUploaded(today, taskProgress, completedTasks, totalTasks);
      } else {
        // Device is online, save data directly to Firebase
        await uploadToFirebase(today, taskProgress, completedTasks, totalTasks);
      }
    }
  }

// Function to save data locally when offline
  Future<void> saveToBeUploaded(String date, List<Map<String, dynamic>> tasks,
      int completedTasks, int totalTasks) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> toBeUploaded =
        prefs.getStringList('toBeUploaded') ?? []; // Existing data

    // Create a new record and encode it as JSON
    Map<String, dynamic> data = {
      'date': date,
      'tasks': tasks,
      'overallCompletion': '$completedTasks /$totalTasks',
    };

    // Add the new record to the list as a JSON string
    toBeUploaded.add(jsonEncode(data));
    await prefs.setStringList('toBeUploaded', toBeUploaded);
  }

// Function to upload data directly to Firebase
  Future<void> uploadToFirebase(String date, List<Map<String, dynamic>> tasks,
      int completedTasks, int totalTasks) async {
    DocumentReference taskRecordDoc = firestore
        .collection('taskRecord')
        .doc(userEmail)
        .collection('records')
        .doc(date);

    await taskRecordDoc.set({
      'tasks': tasks,
      'overallCompletion': '$completedTasks/$totalTasks',
      'date': date,
    });
  }

// Function to upload saved tasks when back online
  Future<void> uploadTasksIfOffline() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> toBeUploaded = prefs.getStringList('toBeUploaded') ?? [];

    for (String record in toBeUploaded) {
      // Parse the saved JSON string back to a map
      Map<String, dynamic> data = jsonDecode(record);
      await uploadToFirebase(
        data['date'],
        List<Map<String, dynamic>>.from(data['tasks']),
        int.parse(data['overallCompletion'].split('/')[0]),
        int.parse(data['overallCompletion'].split('/')[1]),
      );
    }

    // Clear the list after successful upload
    await prefs.remove('toBeUploaded');
  }

// Start network listener to handle offline data upload
  void startNetworkListener() {
    Connectivity().onConnectivityChanged.listen((connectivityResult) async {
      if (connectivityResult != ConnectivityResult.none) {
        await uploadTasksIfOffline().then((_) {
          print('Tasks uploaded successfully.');
        }).catchError((error) {
          print('Error uploading tasks: $error');
        });
      }
    });
  }

  Future<void> loadUserEmail() async {
    User? user = auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email;
      });
    }
  }

  Future<void> printSt() async {
    final prefs = await SharedPreferences.getInstance();
    print(prefs.getStringList('dailyTasks'));

    print(prefs.getString('tDate'));
  }

  Future<void> loadDailyTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Load the saved tasks with status from SharedPreferences
    List<String>? savedTasksJson = prefs.getStringList('defaultTasks') ?? [];
    List<Map<String, dynamic>> savedTasks = [];

    // If there are saved tasks, decode them from JSON
    if (savedTasksJson.isNotEmpty) {
      savedTasks = savedTasksJson
          .map((taskJson) => jsonDecode(taskJson))
          .toList()
          .cast<Map<String, dynamic>>();
      print('Daily tasks fetched from shredPrefrnces');
    } else {
      // If no tasks are found in SharedPreferences, fetch from Firebase
      await fetchDailyTasksFromFirebase();
    }

    // Load the task names (task titles) for the day from SharedPreferences
    List<String>? dailyTasks = prefs.getStringList('dailyTasks') ?? [];

    // Check if dailyTasks is not empty
    if (dailyTasks.isNotEmpty) {
      // Prepare a new list for updated defaultTasks
      List<Map<String, dynamic>> newDefaultTasks = [];

      // Iterate through the dailyTasks and merge with savedTasks to retain their status
      for (String taskName in dailyTasks) {
        // Check if the task already exists in savedTasks
        Map<String, dynamic>? existingTask = savedTasks.firstWhere(
          (task) => task['task'] == taskName,
          orElse: () => {},
        );

        if (existingTask.isNotEmpty) {
          // If the task exists, retain its status
          newDefaultTasks.add(existingTask);
        } else {
          // If it's a new task, add it as incomplete
          newDefaultTasks.add({'task': taskName, 'completed': false});
        }
      }

      // Update the defaultTasks in the state
      setState(() {
        defaultTasks = newDefaultTasks;
      });

      // Save updated defaultTasks back to SharedPreferences
      await saveTasksToSharedPreferences(defaultTasks);
    }
  }

  Future<void> fetchDailyTasksFromFirebase() async {
    try {
      String? userEmail = auth.currentUser?.email;
      if (userEmail != null) {
        // Reference to user's daily tasks in Firebase
        DocumentSnapshot userTasksSnapshot =
            await firestore.collection('dailyTasks').doc(userEmail).get();

        if (userTasksSnapshot.exists) {
          // Extract task data from Firebase
          var data = userTasksSnapshot.data() as Map<String, dynamic>;
          List<dynamic> firebaseTasks = data['tasks'] ?? [];

          // Convert tasks into a usable format
          List<Map<String, dynamic>> fetchedTasks = firebaseTasks.map((task) {
            return {
              'task': task['task'],
              'completed': task['completed'],
            };
          }).toList();

          print('daily tasks fetched from firebase');
          // Save the tasks fetched from Firebase to SharedPreferences
          await saveTasksToSharedPreferences(fetchedTasks);

          // Update the defaultTasks with the fetched data
          setState(() {
            defaultTasks = fetchedTasks;
          });
        } else {
          print("No tasks found in Firebase.");
        }
      }
    } catch (e) {
      print("Error fetching tasks from Firebase: $e");
    }
  }

  void markTaskAsCompleted(String taskName) {
    // Check if the task exists in defaultTasks
    Map<String, dynamic>? task = defaultTasks.firstWhere(
      (task) => task['task'] == taskName,
      orElse: () => {},
    );

    if (task.isNotEmpty) {
      setState(() {
        // Update task status (complete/incomplete)
        task['completed'] = true;

        // Save updated tasks to SharedPreferences
        saveTasksToSharedPreferences(defaultTasks);
      });
    }
  }

  Future<void> deleteTask(String taskName) async {
    print("Attempting to delete task: $taskName");

    // Print current defaultTasks
    print("Current defaultTasks: $defaultTasks");

    // Check if the task exists in defaultTasks
    Map<String, dynamic>? task = defaultTasks.firstWhere(
      (task) => task['task'] == taskName,
      orElse: () => {},
    );

    if (task.isNotEmpty) {
      setState(() async {
        // Remove the task from the defaultTasks
        defaultTasks.removeWhere((element) => element['task'] == taskName);

        // Print updated defaultTasks
        print("Updated defaultTasks: $defaultTasks");

        // Save updated tasks to SharedPreferences
        saveTasksToSharedPreferences(defaultTasks);

        await printSharedPreferencesData();
      });

      // Remove the task from the dailyTasks list in SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? dailyTasks = prefs.getStringList('dailyTasks');
      if (dailyTasks != null) {
        print("Current dailyTasks: $dailyTasks");
        dailyTasks.remove(taskName);
        await prefs.setStringList('dailyTasks', dailyTasks);
        print("Updated dailyTasks: $dailyTasks");
        print("daily task removed from sharedPreferences");
      }
    } else {
      print("Task not found in defaultTasks");
    }
  }

  Future<void> printSharedPreferencesData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedDefaultTasks = prefs.getStringList('defaultTasks');
    List<String>? savedDailyTasks = prefs.getStringList('dailyTasks');

    print("Saved defaultTasks in SharedPreferences: $savedDefaultTasks");
    print("Saved dailyTasks in SharedPreferences: $savedDailyTasks");
  }

  Future<void> saveTasksToSharedPreferences(
      List<Map<String, dynamic>> defaultTasks) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      // Convert updated defaultTasks to JSON strings
      List<String> updatedDefaultTasksJson =
          defaultTasks.map((task) => jsonEncode(task)).toList();

      // Save updated task list to SharedPreferences
      await prefs.setStringList('defaultTasks', updatedDefaultTasksJson);
    } catch (e) {
      print('Error saving tasks to SharedPreferences: $e');
    }
  }

  Future<void> printDefaultTasksWithStatus() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? savedTasksJson = prefs.getStringList('defaultTasks') ?? [];

    if (savedTasksJson.isNotEmpty) {
      try {
        // Print each task with its status
        for (String taskJson in savedTasksJson) {
          Map<String, dynamic> task = jsonDecode(taskJson);
          print('Task: ${task['task']}, Completed: ${task['completed']}');
        }
      } catch (e) {
        print('Error decoding JSON: $e');
      }
    } else {
      print('No tasks found in SharedPreferences.');
    }
  }

  bool isLoading = true;

  Future<void> _handleRefresh() async {
    print("refreshing");
    setState(() {
      isLoading = true;
    });
    checkAndUpdateTasks();
    fetchAdditionalTasks();
    loadDailyTasks();
    saveNormalProgress();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveAdditionalTasksToSharedPreferences(
      List<Map<String, dynamic>> additionalTasks) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> taskList =
        additionalTasks.map((task) => jsonEncode(task)).toList();
    await prefs.setStringList('additionalTasks', taskList);
    print('task saved in sharedPref\n ${taskList}');
  }

  Future<void> saveAdditionalTasksToFirebase(
      List<Map<String, dynamic>> additionalTasks) async {
    String? userEmail = auth.currentUser?.email;
    if (userEmail != null) {
      DocumentReference taskRecordDoc = firestore
          .collection('taskRecord')
          .doc(userEmail)
          .collection('addTasks')
          .doc('tasks');

      await taskRecordDoc.set({
        'tasks': additionalTasks,
      });
    }
    print("task saved in firebase");
  }

  Future<void> createNewAdditionalTask(String taskName) async {
    Map<String, dynamic> newTask = {
      'task': taskName,
      'status': 'incomplete',
    };

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? taskJsonList = prefs.getStringList('additionalTasks');
    List<Map<String, dynamic>> tasks = taskJsonList != null
        ? taskJsonList
            .map((taskJson) => jsonDecode(taskJson))
            .toList()
            .cast<Map<String, dynamic>>()
        : [];

    tasks.add(newTask);
    print('New additional task created !!');

    await saveAdditionalTasksToSharedPreferences(tasks);

    await saveAdditionalTasksToFirebase(tasks);
  }

  Future<void> deleteAdditionalTask(String taskName) async {
    // Fetch existing tasks
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? taskJsonList = prefs.getStringList('additionalTasks');
    if (taskJsonList != null) {
      List<Map<String, dynamic>> tasks = taskJsonList
          .map((taskJson) => jsonDecode(taskJson))
          .toList()
          .cast<Map<String, dynamic>>();

      // Remove task
      tasks.removeWhere((task) => task['task'] == taskName);
      print('Additional tasks removed');

      // Save updated tasks
      await saveAdditionalTasksToSharedPreferences(tasks);
      await saveAdditionalTasksToFirebase(tasks);
    }
  }

  Future<void> updateAdditionalTask(String taskName, bool completed) async {
    // Fetch existing tasks
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? taskJsonList = prefs.getStringList('additionalTasks');
    if (taskJsonList != null) {
      List<Map<String, dynamic>> tasks = taskJsonList
          .map((taskJson) => jsonDecode(taskJson))
          .toList()
          .cast<Map<String, dynamic>>();

      // Update task status
      for (var task in tasks) {
        if (task['task'] == taskName) {
          task['status'] = completed ? 'complete' : 'incomplete';
          print('Additional tasks updated \n ${tasks}');
        }
      }

      // Save updated tasks
      await saveAdditionalTasksToSharedPreferences(tasks);
      await saveAdditionalTasksToFirebase(tasks);
    }
  }

  Future<void> fetchAdditionalTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? taskJsonList = prefs.getStringList('additionalTasks');

    if (taskJsonList == null || taskJsonList.isEmpty) {
      String? userEmail = auth.currentUser?.email;
      if (userEmail != null) {
        DocumentReference taskRecordDoc = firestore
            .collection('taskRecord')
            .doc(userEmail)
            .collection('addTasks')
            .doc('tasks');

        DocumentSnapshot<Object?> querySnapshot = await taskRecordDoc.get();
        print('Additional tasks fetched from firebase');
        if (querySnapshot.exists) {
          List<Map<String, dynamic>> tasks =
              List<Map<String, dynamic>>.from(querySnapshot.get('tasks'));
          List<String> taskJsonList =
              tasks.map((task) => jsonEncode(task)).toList();
          await prefs.setStringList('additionalTasks', taskJsonList);
          setState(() {
            additionalTasks = tasks; // Update the additionalTasks list here
          });
        }
      }
    } else {
      setState(() {
        additionalTasks = taskJsonList
            .map((taskJson) => jsonDecode(taskJson))
            .toList()
            .cast<Map<String, dynamic>>();
      });
    }
    print('Additional tasks fetched from shredPrefrnces');
  }

  @override
  Widget build(BuildContext context) {
    int totalTasks = defaultTasks.length;
    int completedTasks =
        defaultTasks.where((task) => task['completed'] == true).length;
    double taskCompletion = totalTasks > 0 ? completedTasks / totalTasks : 0;
    int daysLeft = DateTime(2025, 1, 1).difference(DateTime.now()).inDays;

    return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              labelType: labelType,
              useIndicator: false,
              indicatorShape: Border.all(width: 20),
              indicatorColor: Colors.transparent,
              minWidth: 15.w,
              groupAlignment: 0,
              backgroundColor:
                  const Color.fromARGB(255, 127, 127, 127).withOpacity(0.1),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) {
                saveNormalProgress();
                setState(() {
                  _selectedIndex = value;
                });
              },
              destinations: [
                NavigationRailDestination(
                  icon: _selectedIndex == 0
                      ? Icon(IconlyLight.home, color: Colors.blue, size: 12.w)
                      : Icon(IconlyBroken.home, size: 9.w),
                  label: Text(
                    'Home',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                ),
                NavigationRailDestination(
                  icon: _selectedIndex == 1
                      ? Icon(IconlyLight.graph, color: Colors.blue, size: 12.w)
                      : Icon(IconlyBroken.graph, size: 9.w),
                  label: Text(
                    'Record',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                ),
                NavigationRailDestination(
                  icon: _selectedIndex == 2
                      ? Icon(IconlyLight.setting,
                          color: Colors.blue, size: 12.w)
                      : Icon(IconlyBroken.setting, size: 9.w),
                  label: Text(
                    'Settings',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(2.w),
                child: _buildContent(),
              ),
            ),
          ],
        ),
        floatingActionButton: _selectedIndex != 0
            ? null
            : SafeArea(
                child: FloatingActionButton(
                  onPressed: () {
                    final _controller = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (context) {
                        return DialogBox(
                          Controller: _controller,
                          onSave: () {
                            if (_controller.text.isNotEmpty) {
                              setState(() {
                                additionalTasks.add({
                                  'task': _controller.text,
                                  'completed': false
                                });
                              });
                              saveAdditionalTasksToSharedPreferences(
                                  additionalTasks);
                              saveAdditionalTasksToFirebase(additionalTasks);
                              Navigator.of(context).pop();
                            }
                          },
                          onCancel: () {
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    );
                  },
                  child: Icon(Icons.add),
                ),
              ));
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return ProgressTracker();
      case 2:
        return UserSettingsPage();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    // fetchAdditionalTasks();
    int totalTasks = defaultTasks.length;
    int completedTasks =
        defaultTasks.where((task) => task['completed'] == true).length;
    double taskCompletion = totalTasks > 0 ? completedTasks / totalTasks : 0;
    int daysLeft = DateTime(DateTime.now().year + 1, 1, 1)
        .difference(DateTime.now())
        .inDays;

    return RefreshIndicator(
      color: Colors.blue,
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FadeInDown(
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 800),
                child: Container(
                  height: 15.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        spreadRadius: 1,
                        color: Colors.grey,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(5.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flash(
                              delay: Duration(milliseconds: 800),
                              duration: Duration(milliseconds: 800),
                              child: Text(
                                '$daysLeft',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.w,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Text(
                              'days left for new year',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 3.w,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        CircularPercentIndicator(
                          radius: 10.w,
                          lineWidth: 8.0,
                          percent: taskCompletion,
                          center: Text(
                            "${(taskCompletion * 100).toStringAsFixed(0)}%",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 5.w,
                              color: Colors.blue,
                            ),
                          ),
                          progressColor: Colors.green,
                          backgroundColor: Colors.grey[300]!,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Daily Tasks:",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 5.w,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            Container(
              height: 40.h,
              child: defaultTasks.isEmpty
                  ? Center(
                      child: Text(
                        'No tasks for today.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 4.w,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : SafeArea(
                      bottom: true,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: defaultTasks.length,
                        itemBuilder: (context, index) {
                          Map<String, dynamic> task = defaultTasks[index];
                          return TaskCard(
                            task: task,
                            onDelete: () {
                              setState(() {
                                defaultTasks.removeAt(index);
                              });
                              deleteTask(task['task']);
                              saveNormalProgress();
                            },
                            onChanged: (value) {
                              setState(() {
                                defaultTasks[index]['completed'] = value!;
                                saveTasksToSharedPreferences(defaultTasks);
                                saveProgress();
                                saveNormalProgress();
                              });
                            },
                          );
                        },
                      ),
                    ),
            ),
            SizedBox(height: 2.h),
            TextButton(
                onPressed: () {
                  printDefaultTasksWithStatus();
                  printSt();
                  checkAndUpdateTasks();
                   Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SplashScreen(),
                                  ),
                                );
                },
                child: Text('button')),
            Text(
              "Additional Tasks:",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 5.w,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: additionalTasks.length,
              itemBuilder: (context, index) {
                return TaskCard(
                  task: additionalTasks[index],
                  onDelete: () {
                    String taskName = additionalTasks[index]['task'];
                    setState(() {
                      additionalTasks
                          .removeWhere((task) => task['task'] == taskName);
                    });
                    deleteAdditionalTask(taskName);
                  },
                  onChanged: (value) {
                    setState(() {
                      additionalTasks[index]['completed'] = value!;
                    });
                    updateAdditionalTask(
                        additionalTasks[index]['task'], value!);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onDelete;
  final ValueChanged<bool?> onChanged;

  const TaskCard({
    required this.task,
    required this.onDelete,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task['task'] + task['completed'].toString()), // Use a unique key
      direction: DismissDirection.startToEnd,
      onDismissed: (direction) => onDelete(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: CheckboxListTile(
          title: Text(
            task['task'],
            style: GoogleFonts.plusJakartaSans(
              decoration: task['completed'] == true
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              color: task['completed'] == true ? Colors.grey : Colors.black,
            ),
          ),
          value: task['completed'] ?? false,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
