import 'package:flutter/material.dart';

// 타임 블럭 페이지
class TimeBlockPage extends StatelessWidget {
  const TimeBlockPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('타임 블록'),
      ),
      body: TimeBlockGrid(
        events: [
          Event(
              day: '월',
              startTime: '9:00',
              endTime: '10:30',
              title: '회의',
              color: Colors.blue),
          Event(
              day: '화',
              startTime: '10:00',
              endTime: '11:00',
              title: '전화',
              color: Colors.green),
          Event(
              day: '수',
              startTime: '13:00',
              endTime: '14:30',
              title: '점심 약속',
              color: Colors.orange),
        ],
      ),
    );
  }
}

// 일정 데이터를 위한 클래스
class Event {
  final String day; // 요일 (예: '월')
  final String startTime; // 시작 시간 (예: '9:00')
  final String endTime; // 종료 시간 (예: '10:30')
  final String title; // 일정 제목 (예: '회의')
  final Color color; // 일정 색상
  Event({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.color,
  });
}

// 타임 블럭 그리드 위젯
class TimeBlockGrid extends StatelessWidget {
  final List<String> timeSlots = [];
  final List<String> days = ['월', '화', '수', '목', '금', '토', '일'];
  final List<Event> events;

  TimeBlockGrid({super.key, required this.events}) {
    // 시간 슬롯 생성 (오전 9시 ~ 오후 10시, 30분 단위)
    for (int hour = 9; hour <= 21; hour++) {
      timeSlots.add('$hour:00');
      timeSlots.add('$hour:30');
    }
    timeSlots.add('22:00'); // 오후 10시 종료 시간 추가
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 요일 헤더
          Row(
            children: [
              Container(
                width: 60,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
              ), // 시간 레이블을 위한 빈 공간
              ...days.map((day) => Expanded(
                    child: Container(
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Text(day),
                    ),
                  )),
            ],
          ),
          // 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: days.length + 1, // 시간 레이블 + 요일
              childAspectRatio: 2,
            ),
            itemCount: timeSlots.length * (days.length + 1),
            itemBuilder: (context, index) {
              int row = index ~/ (days.length + 1);
              int col = index % (days.length + 1);

              if (col == 0) {
                // 시간 레이블
                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 1.5),
                  ),
                  child: Text(timeSlots[row]),
                );
              } else {
                // 요일 셀
                String day = days[col - 1];
                String time = timeSlots[row];
                Event? event = _getEventAt(day, time);
                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 1.5),
                    color: event?.color ?? Colors.white,
                  ),
                  child: Text(event?.title ?? ''),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Event? _getEventAt(String day, String time) {
    for (var event in events) {
      if (event.day == day &&
          _isTimeInRange(time, event.startTime, event.endTime)) {
        return event;
      }
    }
    return null;
  }

  bool _isTimeInRange(String time, String start, String end) {
    int timeMinutes = _timeToMinutes(time);
    int startMinutes = _timeToMinutes(start);
    int endMinutes = _timeToMinutes(end);
    return timeMinutes >= startMinutes && timeMinutes < endMinutes;
  }

  int _timeToMinutes(String time) {
    List<String> parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
