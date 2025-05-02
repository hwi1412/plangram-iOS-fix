import 'package:cloud_firestore/cloud_firestore.dart'; // 추가된 import
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
// 새로 추가된 임포트

// 새 클래스 TodoItem 추가 (Firestore 문서 id 필드 추가)
class TodoItem {
  String text;
  bool completed;
  String? id; // Firestore 문서 id
  TodoItem(this.text, {this.completed = false, this.id});
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  // 초기 _selectedDay를 현재 날짜의 정규화된 값으로 설정
  DateTime _selectedDay =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _highlightedDay; // 선택된 날짜 상태 변수
  CalendarFormat _calendarFormat = CalendarFormat.week; // 기본값을 주간으로 변경

  // 날짜별 To-Do 리스트를 저장하는 상태 변수
  final Map<DateTime, List<TodoItem>> _events = {};

  // 선택된 날짜의 To-Do 리스트 getter (완료 항목은 맨 아래)
  List<TodoItem> get _selectedEvents {
    final events = _events[_selectedDay] ?? <TodoItem>[];
    final sorted = List<TodoItem>.from(events);
    sorted.sort((a, b) => (a.completed ? 1 : 0).compareTo(b.completed ? 1 : 0));
    return sorted;
  }

  // 새 입력을 위한 텍스트 컨트롤러 추가
  final TextEditingController _todoController = TextEditingController();

  // 날짜를 "YYYY-MM-DD" 문자열로 변환하는 도우미 함수
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Firestore에서 저장된 todo list들을 불러오는 함수
  Future<void> _loadTodosFromFirestore() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection("todos").get();
    Map<DateTime, List<TodoItem>> loadedEvents = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      String dateStr = data["date"] ?? "";
      DateTime date = DateTime.parse(dateStr); // ISO 형식이면 바로 파싱
      date = DateTime(date.year, date.month, date.day); // 정규화
      TodoItem todo = TodoItem(data["text"],
          completed: data["completed"] ?? false, id: doc.id);
      if (loadedEvents[date] == null) {
        loadedEvents[date] = [];
      }
      loadedEvents[date]!.add(todo);
    }
    setState(() {
      _events.clear();
      _events.addAll(loadedEvents);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadTodosFromFirestore();
  }

  void _addTodoItem(String todo) {
    final dateString = _formatDate(_selectedDay);
    FirebaseFirestore.instance.collection("todos").add({
      "date": dateString,
      "text": todo,
      "completed": false,
    }).then((docRef) {
      setState(() {
        if (_events[_selectedDay] == null) {
          _events[_selectedDay] = [];
        }
        _events[_selectedDay]!.add(TodoItem(todo, id: docRef.id));
      });
    });
  }

  // 체크박스 상태 변경 시 Firestore 업데이트
  void _updateTodoCompletion(TodoItem item) {
    if (item.id != null) {
      FirebaseFirestore.instance
          .collection("todos")
          .doc(item.id)
          .update({"completed": item.completed});
    }
  }

  // 모달 바닥 시트로 수정 옵션을 제공하는 메서드 수정 (하단 옵션 버튼 행 변경)
  void _showEditOptions() {
    final Set<int> selectedIndices = {};
    showModalBottomSheet(
      backgroundColor: const Color.fromARGB(255, 36, 35, 65),
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더 영역: 좌측 '전체 삭제', 중앙 텍스트, 우측 '수정'
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          // 전체 삭제: 오늘 할 일 모두 삭제 및 Firestore 삭제
                          final currentEvents = _events[_selectedDay] ?? [];
                          for (var item in currentEvents) {
                            if (item.id != null) {
                              FirebaseFirestore.instance
                                  .collection("todos")
                                  .doc(item.id)
                                  .delete();
                            }
                          }
                          setState(() {
                            _events[_selectedDay] = [];
                          });
                          Navigator.pop(context);
                        },
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text("전체 삭제"),
                      ),
                      const Text(
                        "수정 옵션 선택",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          // 수정: 단일 항목 선택 시 수정 팝업 호출
                          if (selectedIndices.length == 1) {
                            final index = selectedIndices.first;
                            final item = _selectedEvents[index];
                            TextEditingController editController =
                                TextEditingController(text: item.text);
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text("할 일 수정"),
                                  content: TextField(
                                    controller: editController,
                                    decoration: const InputDecoration(
                                      hintText: "수정할 내용을 입력하세요",
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text("취소"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          item.text = editController.text;
                                          // Firestore 수정 업데이트
                                          if (item.id != null) {
                                            FirebaseFirestore.instance
                                                .collection("todos")
                                                .doc(item.id)
                                                .update({"text": item.text});
                                          }
                                        });
                                        Navigator.pop(context);
                                        Navigator.pop(context);
                                      },
                                      child: const Text("수정"),
                                    ),
                                  ],
                                );
                              },
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("수정은 하나의 항목만 선택하세요.")),
                            );
                          }
                        },
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text("수정"),
                      ),
                    ],
                  ),
                ),
                // 체크박스로 선택하는 리스트
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _selectedEvents.length,
                    itemBuilder: (context, index) {
                      final item = _selectedEvents[index];
                      final isSelected = selectedIndices.contains(index);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setModalState(() {
                            if (value == true) {
                              selectedIndices.add(index);
                            } else {
                              selectedIndices.remove(index);
                            }
                          });
                        },
                        title: Text(
                          item.text,
                          style: const TextStyle(color: Colors.white),
                        ),
                        activeColor: Colors.green,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),
                // 하단 옵션 버튼 행: 삭제, 복제, 이동, 취소
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        // 삭제: 선택된 항목들을 제거 및 Firestore 삭제
                        final currentEvents = _events[_selectedDay] ?? [];
                        currentEvents.removeWhere((item) {
                          if (selectedIndices
                              .contains(_selectedEvents.indexOf(item))) {
                            if (item.id != null) {
                              FirebaseFirestore.instance
                                  .collection("todos")
                                  .doc(item.id)
                                  .delete();
                            }
                            return true;
                          }
                          return false;
                        });
                        setState(() {
                          _events[_selectedDay] = currentEvents;
                        });
                        Navigator.pop(context);
                      },
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text("삭제"),
                    ),
                    TextButton(
                      onPressed: () {
                        // 복제: 선택된 항목들을 복제하여 추가 및 Firestore 추가
                        final currentEvents = _events[_selectedDay] ?? [];
                        final duplicates = _selectedEvents
                            .asMap()
                            .entries
                            .where(
                                (entry) => selectedIndices.contains(entry.key))
                            .map((entry) {
                          // Firestore 추가 시 duplicate (새 문서 생성)
                          FirebaseFirestore.instance.collection("todos").add({
                            "date": _formatDate(_selectedDay),
                            "text": entry.value.text,
                            "completed": false,
                          }).then((docRef) {
                            setState(() {
                              currentEvents.add(
                                  TodoItem(entry.value.text, id: docRef.id));
                              _events[_selectedDay] = currentEvents;
                            });
                          });
                          return entry.value;
                        }).toList();
                        Navigator.pop(context);
                      },
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text("복제"),
                    ),
                    TextButton(
                      onPressed: () async {
                        DateTime? newDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDay,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (newDate != null) {
                          final normalizedNewDate = DateTime(
                              newDate.year, newDate.month, newDate.day);
                          // 이동할 항목들 가져오기
                          final movingItems = _selectedEvents
                              .asMap()
                              .entries
                              .where((entry) =>
                                  selectedIndices.contains(entry.key))
                              .map((entry) => entry.value)
                              .toList();
                          setState(() {
                            // 현재 날짜에서 해당 항목 제거 + Firestore 업데이트 (삭제)
                            final currentEvents = _events[_selectedDay] ?? [];
                            currentEvents.removeWhere((item) {
                              if (movingItems.contains(item)) {
                                if (item.id != null) {
                                  FirebaseFirestore.instance
                                      .collection("todos")
                                      .doc(item.id)
                                      .delete();
                                }
                                return true;
                              }
                              return false;
                            });
                            _events[_selectedDay] = currentEvents;
                            // 이동할 날짜에 항목 추가 + Firestore 업데이트 (날짜 필드 업데이트)
                            if (_events[normalizedNewDate] == null) {
                              _events[normalizedNewDate] = [];
                            }
                            for (var item in movingItems) {
                              if (item.id != null) {
                                FirebaseFirestore.instance
                                    .collection("todos")
                                    .doc(item.id)
                                    .update({
                                  "date": _formatDate(normalizedNewDate)
                                });
                              }
                              _events[normalizedNewDate]!.add(item);
                            }
                          });
                          Navigator.pop(context);
                        }
                      },
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text("이동"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // 취소
                      },
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text("취소"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'To Do',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        backgroundColor: const Color.fromARGB(255, 25, 25, 37),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 25, 25, 37),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      // 캘린더 클릭 시 월간/주간 토글은 아래 onDaySelected에서 처리
                    },
                    child: TableCalendar(
                      calendarFormat: _calendarFormat,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month',
                        CalendarFormat.week: 'Week',
                      },
                      pageAnimationEnabled: false,
                      firstDay: DateTime.utc(2020, 10, 16),
                      lastDay: DateTime.utc(2030, 3, 14),
                      focusedDay: _selectedDay,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: HeaderStyle(
                        titleTextFormatter: (date, locale) =>
                            "${date.year} / ${date.month.toString().padLeft(2, '0')}",
                        titleTextStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        titleCentered: true,
                        leftChevronIcon:
                            const Icon(Icons.chevron_left, color: Colors.white),
                        rightChevronIcon: const Icon(Icons.chevron_right,
                            color: Colors.white),
                        formatButtonVisible: false,
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: const TextStyle(color: Colors.white),
                        weekendTextStyle: const TextStyle(color: Colors.red),
                        outsideTextStyle:
                            TextStyle(color: Colors.white.withOpacity(0.3)),
                        disabledTextStyle:
                            TextStyle(color: Colors.white.withOpacity(0.3)),
                        todayDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.purple.withOpacity(0.3),
                        ),
                        selectedDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      selectedDayPredicate: (day) {
                        return day.year == _selectedDay.year &&
                            day.month == _selectedDay.month &&
                            day.day == _selectedDay.day;
                      },
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          final normalizedDay =
                              DateTime(day.year, day.month, day.day);
                          final items = _events[normalizedDay] ?? [];
                          if (items.isNotEmpty) {
                            final displayItems = items.take(9).toList();
                            return Positioned(
                              bottom: 1,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  displayItems.length,
                                  (index) => Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: displayItems[index].completed
                                          ? Colors.green
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        final normalized = DateTime(selectedDay.year,
                            selectedDay.month, selectedDay.day);
                        setState(() {
                          if (_calendarFormat == CalendarFormat.week) {
                            // 주간에서 날짜 선택 시 월간으로 전환
                            _calendarFormat = CalendarFormat.month;
                          } else if (_calendarFormat == CalendarFormat.month &&
                              isSameDay(_selectedDay, normalized)) {
                            // 월간에서 같은 날짜를 다시 누르면 주간으로 전환
                            _calendarFormat = CalendarFormat.week;
                          }
                          _selectedDay = normalized;
                          _highlightedDay = normalized;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0), // 왼쪽 여백 추가
                        child: TextButton(
                          onPressed: () {
                            // Rootine 버튼 동작 추가
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("+ Rootine"),
                        ),
                      ),
                      Text(
                        "${_selectedDay.month}.${_selectedDay.day} To Do ",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(right: 16.0), // 오른쪽 여백 추가
                        child: TextButton(
                          onPressed: _showEditOptions,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("수정"),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children:
                            List.generate(_selectedEvents.length, (index) {
                          final item = _selectedEvents[index];
                          return CheckboxListTile(
                            contentPadding: const EdgeInsets.only(left: 50),
                            value: item.completed,
                            activeColor: Colors.green,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              item.text,
                              style: const TextStyle(color: Colors.white),
                            ),
                            onChanged: (value) {
                              setState(() {
                                item.completed = value!;
                                _updateTodoCompletion(item);
                              });
                            },
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 10.0), // 아래에 10 공간 추가
        child: Container(
          color: const Color.fromARGB(255, 31, 31, 43),
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _todoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "할 일을 입력하세요",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(18)), // 모든 모서리 둥글게
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(18)), // 모든 모서리 둥글게
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(18)), // 모든 모서리 둥글게
                      borderSide:
                          const BorderSide(color: Colors.white, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 22),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _addTodoItem(value);
                      _todoController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                color: Colors.grey,
                onPressed: () {
                  if (_todoController.text.isNotEmpty) {
                    _addTodoItem(_todoController.text);
                    _todoController.clear();
                  }
                },
                tooltip: "추가",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
