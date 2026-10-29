// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $CachedQuestionsTable extends CachedQuestions with TableInfo<$CachedQuestionsTable, CachedQuestion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedQuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _examIdMeta = const VerificationMeta('examId');
  @override
  late final GeneratedColumn<int> examId = GeneratedColumn<int>('exam_id', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _subjectIdMeta = const VerificationMeta('subjectId');
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>('subject_id', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>('year', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>('number', aliasedName, true, type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>('body', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta('optionsJson');
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>('answer', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _explanationMeta = const VerificationMeta('explanation');
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>('topic', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imagePathMeta = const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passageIdMeta = const VerificationMeta('passageId');
  @override
  late final GeneratedColumn<String> passageId = GeneratedColumn<String>(
    'passage_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passageTitleMeta = const VerificationMeta('passageTitle');
  @override
  late final GeneratedColumn<String> passageTitle = GeneratedColumn<String>(
    'passage_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passageBodyMeta = const VerificationMeta('passageBody');
  @override
  late final GeneratedColumn<String> passageBody = GeneratedColumn<String>(
    'passage_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    examId,
    subjectId,
    year,
    number,
    body,
    optionsJson,
    answer,
    explanation,
    topic,
    imagePath,
    passageId,
    passageTitle,
    passageBody,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_questions';
  @override
  VerificationContext validateIntegrity(Insertable<CachedQuestion> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exam_id')) {
      context.handle(_examIdMeta, examId.isAcceptableOrUnknown(data['exam_id']!, _examIdMeta));
    } else if (isInserting) {
      context.missing(_examIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(_subjectIdMeta, subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta));
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('year')) {
      context.handle(_yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta, number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('options_json')) {
      context.handle(_optionsJsonMeta, optionsJson.isAcceptableOrUnknown(data['options_json']!, _optionsJsonMeta));
    } else if (isInserting) {
      context.missing(_optionsJsonMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(_answerMeta, answer.isAcceptableOrUnknown(data['answer']!, _answerMeta));
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(_explanationMeta, explanation.isAcceptableOrUnknown(data['explanation']!, _explanationMeta));
    }
    if (data.containsKey('topic')) {
      context.handle(_topicMeta, topic.isAcceptableOrUnknown(data['topic']!, _topicMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta, imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('passage_id')) {
      context.handle(_passageIdMeta, passageId.isAcceptableOrUnknown(data['passage_id']!, _passageIdMeta));
    }
    if (data.containsKey('passage_title')) {
      context.handle(_passageTitleMeta, passageTitle.isAcceptableOrUnknown(data['passage_title']!, _passageTitleMeta));
    }
    if (data.containsKey('passage_body')) {
      context.handle(_passageBodyMeta, passageBody.isAcceptableOrUnknown(data['passage_body']!, _passageBodyMeta));
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta, fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedQuestion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedQuestion(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      examId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}exam_id'])!,
      subjectId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}subject_id'])!,
      year: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}year'])!,
      number: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}number']),
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      optionsJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}options_json'])!,
      answer: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}answer'])!,
      explanation: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}explanation']),
      topic: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}topic']),
      imagePath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}image_path']),
      passageId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}passage_id']),
      passageTitle: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}passage_title']),
      passageBody: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}passage_body']),
      fetchedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $CachedQuestionsTable createAlias(String alias) {
    return $CachedQuestionsTable(attachedDatabase, alias);
  }
}

class CachedQuestion extends DataClass implements Insertable<CachedQuestion> {
  final String id;
  final int examId;
  final int subjectId;
  final int year;
  final int? number;
  final String body;
  final String optionsJson;
  final String answer;
  final String? explanation;
  final String? topic;
  final String? imagePath;
  final String? passageId;
  final String? passageTitle;
  final String? passageBody;
  final DateTime fetchedAt;
  const CachedQuestion({
    required this.id,
    required this.examId,
    required this.subjectId,
    required this.year,
    this.number,
    required this.body,
    required this.optionsJson,
    required this.answer,
    this.explanation,
    this.topic,
    this.imagePath,
    this.passageId,
    this.passageTitle,
    this.passageBody,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exam_id'] = Variable<int>(examId);
    map['subject_id'] = Variable<int>(subjectId);
    map['year'] = Variable<int>(year);
    if (!nullToAbsent || number != null) {
      map['number'] = Variable<int>(number);
    }
    map['body'] = Variable<String>(body);
    map['options_json'] = Variable<String>(optionsJson);
    map['answer'] = Variable<String>(answer);
    if (!nullToAbsent || explanation != null) {
      map['explanation'] = Variable<String>(explanation);
    }
    if (!nullToAbsent || topic != null) {
      map['topic'] = Variable<String>(topic);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || passageId != null) {
      map['passage_id'] = Variable<String>(passageId);
    }
    if (!nullToAbsent || passageTitle != null) {
      map['passage_title'] = Variable<String>(passageTitle);
    }
    if (!nullToAbsent || passageBody != null) {
      map['passage_body'] = Variable<String>(passageBody);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedQuestionsCompanion toCompanion(bool nullToAbsent) {
    return CachedQuestionsCompanion(
      id: Value(id),
      examId: Value(examId),
      subjectId: Value(subjectId),
      year: Value(year),
      number: number == null && nullToAbsent ? const Value.absent() : Value(number),
      body: Value(body),
      optionsJson: Value(optionsJson),
      answer: Value(answer),
      explanation: explanation == null && nullToAbsent ? const Value.absent() : Value(explanation),
      topic: topic == null && nullToAbsent ? const Value.absent() : Value(topic),
      imagePath: imagePath == null && nullToAbsent ? const Value.absent() : Value(imagePath),
      passageId: passageId == null && nullToAbsent ? const Value.absent() : Value(passageId),
      passageTitle: passageTitle == null && nullToAbsent ? const Value.absent() : Value(passageTitle),
      passageBody: passageBody == null && nullToAbsent ? const Value.absent() : Value(passageBody),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedQuestion.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedQuestion(
      id: serializer.fromJson<String>(json['id']),
      examId: serializer.fromJson<int>(json['examId']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      year: serializer.fromJson<int>(json['year']),
      number: serializer.fromJson<int?>(json['number']),
      body: serializer.fromJson<String>(json['body']),
      optionsJson: serializer.fromJson<String>(json['optionsJson']),
      answer: serializer.fromJson<String>(json['answer']),
      explanation: serializer.fromJson<String?>(json['explanation']),
      topic: serializer.fromJson<String?>(json['topic']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      passageId: serializer.fromJson<String?>(json['passageId']),
      passageTitle: serializer.fromJson<String?>(json['passageTitle']),
      passageBody: serializer.fromJson<String?>(json['passageBody']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'examId': serializer.toJson<int>(examId),
      'subjectId': serializer.toJson<int>(subjectId),
      'year': serializer.toJson<int>(year),
      'number': serializer.toJson<int?>(number),
      'body': serializer.toJson<String>(body),
      'optionsJson': serializer.toJson<String>(optionsJson),
      'answer': serializer.toJson<String>(answer),
      'explanation': serializer.toJson<String?>(explanation),
      'topic': serializer.toJson<String?>(topic),
      'imagePath': serializer.toJson<String?>(imagePath),
      'passageId': serializer.toJson<String?>(passageId),
      'passageTitle': serializer.toJson<String?>(passageTitle),
      'passageBody': serializer.toJson<String?>(passageBody),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedQuestion copyWith({
    String? id,
    int? examId,
    int? subjectId,
    int? year,
    Value<int?> number = const Value.absent(),
    String? body,
    String? optionsJson,
    String? answer,
    Value<String?> explanation = const Value.absent(),
    Value<String?> topic = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
    Value<String?> passageId = const Value.absent(),
    Value<String?> passageTitle = const Value.absent(),
    Value<String?> passageBody = const Value.absent(),
    DateTime? fetchedAt,
  }) => CachedQuestion(
    id: id ?? this.id,
    examId: examId ?? this.examId,
    subjectId: subjectId ?? this.subjectId,
    year: year ?? this.year,
    number: number.present ? number.value : this.number,
    body: body ?? this.body,
    optionsJson: optionsJson ?? this.optionsJson,
    answer: answer ?? this.answer,
    explanation: explanation.present ? explanation.value : this.explanation,
    topic: topic.present ? topic.value : this.topic,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    passageId: passageId.present ? passageId.value : this.passageId,
    passageTitle: passageTitle.present ? passageTitle.value : this.passageTitle,
    passageBody: passageBody.present ? passageBody.value : this.passageBody,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedQuestion copyWithCompanion(CachedQuestionsCompanion data) {
    return CachedQuestion(
      id: data.id.present ? data.id.value : this.id,
      examId: data.examId.present ? data.examId.value : this.examId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      year: data.year.present ? data.year.value : this.year,
      number: data.number.present ? data.number.value : this.number,
      body: data.body.present ? data.body.value : this.body,
      optionsJson: data.optionsJson.present ? data.optionsJson.value : this.optionsJson,
      answer: data.answer.present ? data.answer.value : this.answer,
      explanation: data.explanation.present ? data.explanation.value : this.explanation,
      topic: data.topic.present ? data.topic.value : this.topic,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      passageId: data.passageId.present ? data.passageId.value : this.passageId,
      passageTitle: data.passageTitle.present ? data.passageTitle.value : this.passageTitle,
      passageBody: data.passageBody.present ? data.passageBody.value : this.passageBody,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedQuestion(')
          ..write('id: $id, ')
          ..write('examId: $examId, ')
          ..write('subjectId: $subjectId, ')
          ..write('year: $year, ')
          ..write('number: $number, ')
          ..write('body: $body, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('answer: $answer, ')
          ..write('explanation: $explanation, ')
          ..write('topic: $topic, ')
          ..write('imagePath: $imagePath, ')
          ..write('passageId: $passageId, ')
          ..write('passageTitle: $passageTitle, ')
          ..write('passageBody: $passageBody, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    examId,
    subjectId,
    year,
    number,
    body,
    optionsJson,
    answer,
    explanation,
    topic,
    imagePath,
    passageId,
    passageTitle,
    passageBody,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedQuestion &&
          other.id == this.id &&
          other.examId == this.examId &&
          other.subjectId == this.subjectId &&
          other.year == this.year &&
          other.number == this.number &&
          other.body == this.body &&
          other.optionsJson == this.optionsJson &&
          other.answer == this.answer &&
          other.explanation == this.explanation &&
          other.topic == this.topic &&
          other.imagePath == this.imagePath &&
          other.passageId == this.passageId &&
          other.passageTitle == this.passageTitle &&
          other.passageBody == this.passageBody &&
          other.fetchedAt == this.fetchedAt);
}

class CachedQuestionsCompanion extends UpdateCompanion<CachedQuestion> {
  final Value<String> id;
  final Value<int> examId;
  final Value<int> subjectId;
  final Value<int> year;
  final Value<int?> number;
  final Value<String> body;
  final Value<String> optionsJson;
  final Value<String> answer;
  final Value<String?> explanation;
  final Value<String?> topic;
  final Value<String?> imagePath;
  final Value<String?> passageId;
  final Value<String?> passageTitle;
  final Value<String?> passageBody;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedQuestionsCompanion({
    this.id = const Value.absent(),
    this.examId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.year = const Value.absent(),
    this.number = const Value.absent(),
    this.body = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.answer = const Value.absent(),
    this.explanation = const Value.absent(),
    this.topic = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.passageId = const Value.absent(),
    this.passageTitle = const Value.absent(),
    this.passageBody = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedQuestionsCompanion.insert({
    required String id,
    required int examId,
    required int subjectId,
    required int year,
    this.number = const Value.absent(),
    required String body,
    required String optionsJson,
    required String answer,
    this.explanation = const Value.absent(),
    this.topic = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.passageId = const Value.absent(),
    this.passageTitle = const Value.absent(),
    this.passageBody = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       examId = Value(examId),
       subjectId = Value(subjectId),
       year = Value(year),
       body = Value(body),
       optionsJson = Value(optionsJson),
       answer = Value(answer);
  static Insertable<CachedQuestion> custom({
    Expression<String>? id,
    Expression<int>? examId,
    Expression<int>? subjectId,
    Expression<int>? year,
    Expression<int>? number,
    Expression<String>? body,
    Expression<String>? optionsJson,
    Expression<String>? answer,
    Expression<String>? explanation,
    Expression<String>? topic,
    Expression<String>? imagePath,
    Expression<String>? passageId,
    Expression<String>? passageTitle,
    Expression<String>? passageBody,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (examId != null) 'exam_id': examId,
      if (subjectId != null) 'subject_id': subjectId,
      if (year != null) 'year': year,
      if (number != null) 'number': number,
      if (body != null) 'body': body,
      if (optionsJson != null) 'options_json': optionsJson,
      if (answer != null) 'answer': answer,
      if (explanation != null) 'explanation': explanation,
      if (topic != null) 'topic': topic,
      if (imagePath != null) 'image_path': imagePath,
      if (passageId != null) 'passage_id': passageId,
      if (passageTitle != null) 'passage_title': passageTitle,
      if (passageBody != null) 'passage_body': passageBody,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedQuestionsCompanion copyWith({
    Value<String>? id,
    Value<int>? examId,
    Value<int>? subjectId,
    Value<int>? year,
    Value<int?>? number,
    Value<String>? body,
    Value<String>? optionsJson,
    Value<String>? answer,
    Value<String?>? explanation,
    Value<String?>? topic,
    Value<String?>? imagePath,
    Value<String?>? passageId,
    Value<String?>? passageTitle,
    Value<String?>? passageBody,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return CachedQuestionsCompanion(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      subjectId: subjectId ?? this.subjectId,
      year: year ?? this.year,
      number: number ?? this.number,
      body: body ?? this.body,
      optionsJson: optionsJson ?? this.optionsJson,
      answer: answer ?? this.answer,
      explanation: explanation ?? this.explanation,
      topic: topic ?? this.topic,
      imagePath: imagePath ?? this.imagePath,
      passageId: passageId ?? this.passageId,
      passageTitle: passageTitle ?? this.passageTitle,
      passageBody: passageBody ?? this.passageBody,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (examId.present) {
      map['exam_id'] = Variable<int>(examId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (passageId.present) {
      map['passage_id'] = Variable<String>(passageId.value);
    }
    if (passageTitle.present) {
      map['passage_title'] = Variable<String>(passageTitle.value);
    }
    if (passageBody.present) {
      map['passage_body'] = Variable<String>(passageBody.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedQuestionsCompanion(')
          ..write('id: $id, ')
          ..write('examId: $examId, ')
          ..write('subjectId: $subjectId, ')
          ..write('year: $year, ')
          ..write('number: $number, ')
          ..write('body: $body, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('answer: $answer, ')
          ..write('explanation: $explanation, ')
          ..write('topic: $topic, ')
          ..write('imagePath: $imagePath, ')
          ..write('passageId: $passageId, ')
          ..write('passageTitle: $passageTitle, ')
          ..write('passageBody: $passageBody, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAttemptsTable extends LocalAttempts with TableInfo<$LocalAttemptsTable, LocalAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _examIdMeta = const VerificationMeta('examId');
  @override
  late final GeneratedColumn<int> examId = GeneratedColumn<int>('exam_id', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _examCodeMeta = const VerificationMeta('examCode');
  @override
  late final GeneratedColumn<String> examCode = GeneratedColumn<String>('exam_code', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>('mode', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _configJsonMeta = const VerificationMeta('configJson');
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionIdsJsonMeta = const VerificationMeta('questionIdsJson');
  @override
  late final GeneratedColumn<String> questionIdsJson = GeneratedColumn<String>(
    'question_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _limitSecondsMeta = const VerificationMeta('limitSeconds');
  @override
  late final GeneratedColumn<int> limitSeconds = GeneratedColumn<int>('limit_seconds', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _usedMsMeta = const VerificationMeta('usedMs');
  @override
  late final GeneratedColumn<int> usedMs = GeneratedColumn<int>(
    'used_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentIndexMeta = const VerificationMeta('currentIndex');
  @override
  late final GeneratedColumn<int> currentIndex = GeneratedColumn<int>(
    'current_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _submittedAtMeta = const VerificationMeta('submittedAt');
  @override
  late final GeneratedColumn<DateTime> submittedAt = GeneratedColumn<DateTime>(
    'submitted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientScoreJsonMeta = const VerificationMeta('clientScoreJson');
  @override
  late final GeneratedColumn<String> clientScoreJson = GeneratedColumn<String>(
    'client_score_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverScoreJsonMeta = const VerificationMeta('serverScoreJson');
  @override
  late final GeneratedColumn<String> serverScoreJson = GeneratedColumn<String>(
    'server_score_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    examId,
    examCode,
    mode,
    configJson,
    questionIdsJson,
    limitSeconds,
    usedMs,
    currentIndex,
    startedAt,
    submittedAt,
    clientScoreJson,
    serverScoreJson,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_attempts';
  @override
  VerificationContext validateIntegrity(Insertable<LocalAttempt> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exam_id')) {
      context.handle(_examIdMeta, examId.isAcceptableOrUnknown(data['exam_id']!, _examIdMeta));
    } else if (isInserting) {
      context.missing(_examIdMeta);
    }
    if (data.containsKey('exam_code')) {
      context.handle(_examCodeMeta, examCode.isAcceptableOrUnknown(data['exam_code']!, _examCodeMeta));
    } else if (isInserting) {
      context.missing(_examCodeMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(_modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('config_json')) {
      context.handle(_configJsonMeta, configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta));
    } else if (isInserting) {
      context.missing(_configJsonMeta);
    }
    if (data.containsKey('question_ids_json')) {
      context.handle(_questionIdsJsonMeta, questionIdsJson.isAcceptableOrUnknown(data['question_ids_json']!, _questionIdsJsonMeta));
    } else if (isInserting) {
      context.missing(_questionIdsJsonMeta);
    }
    if (data.containsKey('limit_seconds')) {
      context.handle(_limitSecondsMeta, limitSeconds.isAcceptableOrUnknown(data['limit_seconds']!, _limitSecondsMeta));
    } else if (isInserting) {
      context.missing(_limitSecondsMeta);
    }
    if (data.containsKey('used_ms')) {
      context.handle(_usedMsMeta, usedMs.isAcceptableOrUnknown(data['used_ms']!, _usedMsMeta));
    }
    if (data.containsKey('current_index')) {
      context.handle(_currentIndexMeta, currentIndex.isAcceptableOrUnknown(data['current_index']!, _currentIndexMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta, startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('submitted_at')) {
      context.handle(_submittedAtMeta, submittedAt.isAcceptableOrUnknown(data['submitted_at']!, _submittedAtMeta));
    }
    if (data.containsKey('client_score_json')) {
      context.handle(_clientScoreJsonMeta, clientScoreJson.isAcceptableOrUnknown(data['client_score_json']!, _clientScoreJsonMeta));
    }
    if (data.containsKey('server_score_json')) {
      context.handle(_serverScoreJsonMeta, serverScoreJson.isAcceptableOrUnknown(data['server_score_json']!, _serverScoreJsonMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta, synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttempt(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      examId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}exam_id'])!,
      examCode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}exam_code'])!,
      mode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      configJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}config_json'])!,
      questionIdsJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}question_ids_json'])!,
      limitSeconds: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}limit_seconds'])!,
      usedMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}used_ms'])!,
      currentIndex: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}current_index'])!,
      startedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      submittedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}submitted_at']),
      clientScoreJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}client_score_json']),
      serverScoreJson: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}server_score_json']),
      synced: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $LocalAttemptsTable createAlias(String alias) {
    return $LocalAttemptsTable(attachedDatabase, alias);
  }
}

class LocalAttempt extends DataClass implements Insertable<LocalAttempt> {
  final String id;
  final int examId;
  final String examCode;
  final String mode;
  final String configJson;
  final String questionIdsJson;
  final int limitSeconds;
  final int usedMs;
  final int currentIndex;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final String? clientScoreJson;
  final String? serverScoreJson;
  final bool synced;
  const LocalAttempt({
    required this.id,
    required this.examId,
    required this.examCode,
    required this.mode,
    required this.configJson,
    required this.questionIdsJson,
    required this.limitSeconds,
    required this.usedMs,
    required this.currentIndex,
    required this.startedAt,
    this.submittedAt,
    this.clientScoreJson,
    this.serverScoreJson,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exam_id'] = Variable<int>(examId);
    map['exam_code'] = Variable<String>(examCode);
    map['mode'] = Variable<String>(mode);
    map['config_json'] = Variable<String>(configJson);
    map['question_ids_json'] = Variable<String>(questionIdsJson);
    map['limit_seconds'] = Variable<int>(limitSeconds);
    map['used_ms'] = Variable<int>(usedMs);
    map['current_index'] = Variable<int>(currentIndex);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || submittedAt != null) {
      map['submitted_at'] = Variable<DateTime>(submittedAt);
    }
    if (!nullToAbsent || clientScoreJson != null) {
      map['client_score_json'] = Variable<String>(clientScoreJson);
    }
    if (!nullToAbsent || serverScoreJson != null) {
      map['server_score_json'] = Variable<String>(serverScoreJson);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  LocalAttemptsCompanion toCompanion(bool nullToAbsent) {
    return LocalAttemptsCompanion(
      id: Value(id),
      examId: Value(examId),
      examCode: Value(examCode),
      mode: Value(mode),
      configJson: Value(configJson),
      questionIdsJson: Value(questionIdsJson),
      limitSeconds: Value(limitSeconds),
      usedMs: Value(usedMs),
      currentIndex: Value(currentIndex),
      startedAt: Value(startedAt),
      submittedAt: submittedAt == null && nullToAbsent ? const Value.absent() : Value(submittedAt),
      clientScoreJson: clientScoreJson == null && nullToAbsent ? const Value.absent() : Value(clientScoreJson),
      serverScoreJson: serverScoreJson == null && nullToAbsent ? const Value.absent() : Value(serverScoreJson),
      synced: Value(synced),
    );
  }

  factory LocalAttempt.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttempt(
      id: serializer.fromJson<String>(json['id']),
      examId: serializer.fromJson<int>(json['examId']),
      examCode: serializer.fromJson<String>(json['examCode']),
      mode: serializer.fromJson<String>(json['mode']),
      configJson: serializer.fromJson<String>(json['configJson']),
      questionIdsJson: serializer.fromJson<String>(json['questionIdsJson']),
      limitSeconds: serializer.fromJson<int>(json['limitSeconds']),
      usedMs: serializer.fromJson<int>(json['usedMs']),
      currentIndex: serializer.fromJson<int>(json['currentIndex']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      submittedAt: serializer.fromJson<DateTime?>(json['submittedAt']),
      clientScoreJson: serializer.fromJson<String?>(json['clientScoreJson']),
      serverScoreJson: serializer.fromJson<String?>(json['serverScoreJson']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'examId': serializer.toJson<int>(examId),
      'examCode': serializer.toJson<String>(examCode),
      'mode': serializer.toJson<String>(mode),
      'configJson': serializer.toJson<String>(configJson),
      'questionIdsJson': serializer.toJson<String>(questionIdsJson),
      'limitSeconds': serializer.toJson<int>(limitSeconds),
      'usedMs': serializer.toJson<int>(usedMs),
      'currentIndex': serializer.toJson<int>(currentIndex),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'submittedAt': serializer.toJson<DateTime?>(submittedAt),
      'clientScoreJson': serializer.toJson<String?>(clientScoreJson),
      'serverScoreJson': serializer.toJson<String?>(serverScoreJson),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  LocalAttempt copyWith({
    String? id,
    int? examId,
    String? examCode,
    String? mode,
    String? configJson,
    String? questionIdsJson,
    int? limitSeconds,
    int? usedMs,
    int? currentIndex,
    DateTime? startedAt,
    Value<DateTime?> submittedAt = const Value.absent(),
    Value<String?> clientScoreJson = const Value.absent(),
    Value<String?> serverScoreJson = const Value.absent(),
    bool? synced,
  }) => LocalAttempt(
    id: id ?? this.id,
    examId: examId ?? this.examId,
    examCode: examCode ?? this.examCode,
    mode: mode ?? this.mode,
    configJson: configJson ?? this.configJson,
    questionIdsJson: questionIdsJson ?? this.questionIdsJson,
    limitSeconds: limitSeconds ?? this.limitSeconds,
    usedMs: usedMs ?? this.usedMs,
    currentIndex: currentIndex ?? this.currentIndex,
    startedAt: startedAt ?? this.startedAt,
    submittedAt: submittedAt.present ? submittedAt.value : this.submittedAt,
    clientScoreJson: clientScoreJson.present ? clientScoreJson.value : this.clientScoreJson,
    serverScoreJson: serverScoreJson.present ? serverScoreJson.value : this.serverScoreJson,
    synced: synced ?? this.synced,
  );
  LocalAttempt copyWithCompanion(LocalAttemptsCompanion data) {
    return LocalAttempt(
      id: data.id.present ? data.id.value : this.id,
      examId: data.examId.present ? data.examId.value : this.examId,
      examCode: data.examCode.present ? data.examCode.value : this.examCode,
      mode: data.mode.present ? data.mode.value : this.mode,
      configJson: data.configJson.present ? data.configJson.value : this.configJson,
      questionIdsJson: data.questionIdsJson.present ? data.questionIdsJson.value : this.questionIdsJson,
      limitSeconds: data.limitSeconds.present ? data.limitSeconds.value : this.limitSeconds,
      usedMs: data.usedMs.present ? data.usedMs.value : this.usedMs,
      currentIndex: data.currentIndex.present ? data.currentIndex.value : this.currentIndex,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      submittedAt: data.submittedAt.present ? data.submittedAt.value : this.submittedAt,
      clientScoreJson: data.clientScoreJson.present ? data.clientScoreJson.value : this.clientScoreJson,
      serverScoreJson: data.serverScoreJson.present ? data.serverScoreJson.value : this.serverScoreJson,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttempt(')
          ..write('id: $id, ')
          ..write('examId: $examId, ')
          ..write('examCode: $examCode, ')
          ..write('mode: $mode, ')
          ..write('configJson: $configJson, ')
          ..write('questionIdsJson: $questionIdsJson, ')
          ..write('limitSeconds: $limitSeconds, ')
          ..write('usedMs: $usedMs, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('startedAt: $startedAt, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('clientScoreJson: $clientScoreJson, ')
          ..write('serverScoreJson: $serverScoreJson, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    examId,
    examCode,
    mode,
    configJson,
    questionIdsJson,
    limitSeconds,
    usedMs,
    currentIndex,
    startedAt,
    submittedAt,
    clientScoreJson,
    serverScoreJson,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttempt &&
          other.id == this.id &&
          other.examId == this.examId &&
          other.examCode == this.examCode &&
          other.mode == this.mode &&
          other.configJson == this.configJson &&
          other.questionIdsJson == this.questionIdsJson &&
          other.limitSeconds == this.limitSeconds &&
          other.usedMs == this.usedMs &&
          other.currentIndex == this.currentIndex &&
          other.startedAt == this.startedAt &&
          other.submittedAt == this.submittedAt &&
          other.clientScoreJson == this.clientScoreJson &&
          other.serverScoreJson == this.serverScoreJson &&
          other.synced == this.synced);
}

class LocalAttemptsCompanion extends UpdateCompanion<LocalAttempt> {
  final Value<String> id;
  final Value<int> examId;
  final Value<String> examCode;
  final Value<String> mode;
  final Value<String> configJson;
  final Value<String> questionIdsJson;
  final Value<int> limitSeconds;
  final Value<int> usedMs;
  final Value<int> currentIndex;
  final Value<DateTime> startedAt;
  final Value<DateTime?> submittedAt;
  final Value<String?> clientScoreJson;
  final Value<String?> serverScoreJson;
  final Value<bool> synced;
  final Value<int> rowid;
  const LocalAttemptsCompanion({
    this.id = const Value.absent(),
    this.examId = const Value.absent(),
    this.examCode = const Value.absent(),
    this.mode = const Value.absent(),
    this.configJson = const Value.absent(),
    this.questionIdsJson = const Value.absent(),
    this.limitSeconds = const Value.absent(),
    this.usedMs = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.clientScoreJson = const Value.absent(),
    this.serverScoreJson = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAttemptsCompanion.insert({
    required String id,
    required int examId,
    required String examCode,
    required String mode,
    required String configJson,
    required String questionIdsJson,
    required int limitSeconds,
    this.usedMs = const Value.absent(),
    this.currentIndex = const Value.absent(),
    required DateTime startedAt,
    this.submittedAt = const Value.absent(),
    this.clientScoreJson = const Value.absent(),
    this.serverScoreJson = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       examId = Value(examId),
       examCode = Value(examCode),
       mode = Value(mode),
       configJson = Value(configJson),
       questionIdsJson = Value(questionIdsJson),
       limitSeconds = Value(limitSeconds),
       startedAt = Value(startedAt);
  static Insertable<LocalAttempt> custom({
    Expression<String>? id,
    Expression<int>? examId,
    Expression<String>? examCode,
    Expression<String>? mode,
    Expression<String>? configJson,
    Expression<String>? questionIdsJson,
    Expression<int>? limitSeconds,
    Expression<int>? usedMs,
    Expression<int>? currentIndex,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? submittedAt,
    Expression<String>? clientScoreJson,
    Expression<String>? serverScoreJson,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (examId != null) 'exam_id': examId,
      if (examCode != null) 'exam_code': examCode,
      if (mode != null) 'mode': mode,
      if (configJson != null) 'config_json': configJson,
      if (questionIdsJson != null) 'question_ids_json': questionIdsJson,
      if (limitSeconds != null) 'limit_seconds': limitSeconds,
      if (usedMs != null) 'used_ms': usedMs,
      if (currentIndex != null) 'current_index': currentIndex,
      if (startedAt != null) 'started_at': startedAt,
      if (submittedAt != null) 'submitted_at': submittedAt,
      if (clientScoreJson != null) 'client_score_json': clientScoreJson,
      if (serverScoreJson != null) 'server_score_json': serverScoreJson,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAttemptsCompanion copyWith({
    Value<String>? id,
    Value<int>? examId,
    Value<String>? examCode,
    Value<String>? mode,
    Value<String>? configJson,
    Value<String>? questionIdsJson,
    Value<int>? limitSeconds,
    Value<int>? usedMs,
    Value<int>? currentIndex,
    Value<DateTime>? startedAt,
    Value<DateTime?>? submittedAt,
    Value<String?>? clientScoreJson,
    Value<String?>? serverScoreJson,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return LocalAttemptsCompanion(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      examCode: examCode ?? this.examCode,
      mode: mode ?? this.mode,
      configJson: configJson ?? this.configJson,
      questionIdsJson: questionIdsJson ?? this.questionIdsJson,
      limitSeconds: limitSeconds ?? this.limitSeconds,
      usedMs: usedMs ?? this.usedMs,
      currentIndex: currentIndex ?? this.currentIndex,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      clientScoreJson: clientScoreJson ?? this.clientScoreJson,
      serverScoreJson: serverScoreJson ?? this.serverScoreJson,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (examId.present) {
      map['exam_id'] = Variable<int>(examId.value);
    }
    if (examCode.present) {
      map['exam_code'] = Variable<String>(examCode.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (questionIdsJson.present) {
      map['question_ids_json'] = Variable<String>(questionIdsJson.value);
    }
    if (limitSeconds.present) {
      map['limit_seconds'] = Variable<int>(limitSeconds.value);
    }
    if (usedMs.present) {
      map['used_ms'] = Variable<int>(usedMs.value);
    }
    if (currentIndex.present) {
      map['current_index'] = Variable<int>(currentIndex.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (submittedAt.present) {
      map['submitted_at'] = Variable<DateTime>(submittedAt.value);
    }
    if (clientScoreJson.present) {
      map['client_score_json'] = Variable<String>(clientScoreJson.value);
    }
    if (serverScoreJson.present) {
      map['server_score_json'] = Variable<String>(serverScoreJson.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttemptsCompanion(')
          ..write('id: $id, ')
          ..write('examId: $examId, ')
          ..write('examCode: $examCode, ')
          ..write('mode: $mode, ')
          ..write('configJson: $configJson, ')
          ..write('questionIdsJson: $questionIdsJson, ')
          ..write('limitSeconds: $limitSeconds, ')
          ..write('usedMs: $usedMs, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('startedAt: $startedAt, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('clientScoreJson: $clientScoreJson, ')
          ..write('serverScoreJson: $serverScoreJson, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAnswersTable extends LocalAnswers with TableInfo<$LocalAnswersTable, LocalAnswer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAnswersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _attemptIdMeta = const VerificationMeta('attemptId');
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES local_attempts (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta('questionId');
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _choiceMeta = const VerificationMeta('choice');
  @override
  late final GeneratedColumn<String> choice = GeneratedColumn<String>('choice', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _flaggedMeta = const VerificationMeta('flagged');
  @override
  late final GeneratedColumn<bool> flagged = GeneratedColumn<bool>(
    'flagged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("flagged" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _timeMsMeta = const VerificationMeta('timeMs');
  @override
  late final GeneratedColumn<int> timeMs = GeneratedColumn<int>(
    'time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [attemptId, questionId, choice, flagged, timeMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_answers';
  @override
  VerificationContext validateIntegrity(Insertable<LocalAnswer> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('attempt_id')) {
      context.handle(_attemptIdMeta, attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta));
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(_questionIdMeta, questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta));
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('choice')) {
      context.handle(_choiceMeta, choice.isAcceptableOrUnknown(data['choice']!, _choiceMeta));
    }
    if (data.containsKey('flagged')) {
      context.handle(_flaggedMeta, flagged.isAcceptableOrUnknown(data['flagged']!, _flaggedMeta));
    }
    if (data.containsKey('time_ms')) {
      context.handle(_timeMsMeta, timeMs.isAcceptableOrUnknown(data['time_ms']!, _timeMsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {attemptId, questionId};
  @override
  LocalAnswer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAnswer(
      attemptId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}attempt_id'])!,
      questionId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}question_id'])!,
      choice: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}choice']),
      flagged: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}flagged'])!,
      timeMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}time_ms'])!,
    );
  }

  @override
  $LocalAnswersTable createAlias(String alias) {
    return $LocalAnswersTable(attachedDatabase, alias);
  }
}

class LocalAnswer extends DataClass implements Insertable<LocalAnswer> {
  final String attemptId;
  final String questionId;
  final String? choice;
  final bool flagged;
  final int timeMs;
  const LocalAnswer({required this.attemptId, required this.questionId, this.choice, required this.flagged, required this.timeMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['attempt_id'] = Variable<String>(attemptId);
    map['question_id'] = Variable<String>(questionId);
    if (!nullToAbsent || choice != null) {
      map['choice'] = Variable<String>(choice);
    }
    map['flagged'] = Variable<bool>(flagged);
    map['time_ms'] = Variable<int>(timeMs);
    return map;
  }

  LocalAnswersCompanion toCompanion(bool nullToAbsent) {
    return LocalAnswersCompanion(
      attemptId: Value(attemptId),
      questionId: Value(questionId),
      choice: choice == null && nullToAbsent ? const Value.absent() : Value(choice),
      flagged: Value(flagged),
      timeMs: Value(timeMs),
    );
  }

  factory LocalAnswer.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAnswer(
      attemptId: serializer.fromJson<String>(json['attemptId']),
      questionId: serializer.fromJson<String>(json['questionId']),
      choice: serializer.fromJson<String?>(json['choice']),
      flagged: serializer.fromJson<bool>(json['flagged']),
      timeMs: serializer.fromJson<int>(json['timeMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'attemptId': serializer.toJson<String>(attemptId),
      'questionId': serializer.toJson<String>(questionId),
      'choice': serializer.toJson<String?>(choice),
      'flagged': serializer.toJson<bool>(flagged),
      'timeMs': serializer.toJson<int>(timeMs),
    };
  }

  LocalAnswer copyWith({String? attemptId, String? questionId, Value<String?> choice = const Value.absent(), bool? flagged, int? timeMs}) => LocalAnswer(
    attemptId: attemptId ?? this.attemptId,
    questionId: questionId ?? this.questionId,
    choice: choice.present ? choice.value : this.choice,
    flagged: flagged ?? this.flagged,
    timeMs: timeMs ?? this.timeMs,
  );
  LocalAnswer copyWithCompanion(LocalAnswersCompanion data) {
    return LocalAnswer(
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      questionId: data.questionId.present ? data.questionId.value : this.questionId,
      choice: data.choice.present ? data.choice.value : this.choice,
      flagged: data.flagged.present ? data.flagged.value : this.flagged,
      timeMs: data.timeMs.present ? data.timeMs.value : this.timeMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAnswer(')
          ..write('attemptId: $attemptId, ')
          ..write('questionId: $questionId, ')
          ..write('choice: $choice, ')
          ..write('flagged: $flagged, ')
          ..write('timeMs: $timeMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(attemptId, questionId, choice, flagged, timeMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAnswer &&
          other.attemptId == this.attemptId &&
          other.questionId == this.questionId &&
          other.choice == this.choice &&
          other.flagged == this.flagged &&
          other.timeMs == this.timeMs);
}

class LocalAnswersCompanion extends UpdateCompanion<LocalAnswer> {
  final Value<String> attemptId;
  final Value<String> questionId;
  final Value<String?> choice;
  final Value<bool> flagged;
  final Value<int> timeMs;
  final Value<int> rowid;
  const LocalAnswersCompanion({
    this.attemptId = const Value.absent(),
    this.questionId = const Value.absent(),
    this.choice = const Value.absent(),
    this.flagged = const Value.absent(),
    this.timeMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAnswersCompanion.insert({
    required String attemptId,
    required String questionId,
    this.choice = const Value.absent(),
    this.flagged = const Value.absent(),
    this.timeMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : attemptId = Value(attemptId),
       questionId = Value(questionId);
  static Insertable<LocalAnswer> custom({
    Expression<String>? attemptId,
    Expression<String>? questionId,
    Expression<String>? choice,
    Expression<bool>? flagged,
    Expression<int>? timeMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (attemptId != null) 'attempt_id': attemptId,
      if (questionId != null) 'question_id': questionId,
      if (choice != null) 'choice': choice,
      if (flagged != null) 'flagged': flagged,
      if (timeMs != null) 'time_ms': timeMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAnswersCompanion copyWith({
    Value<String>? attemptId,
    Value<String>? questionId,
    Value<String?>? choice,
    Value<bool>? flagged,
    Value<int>? timeMs,
    Value<int>? rowid,
  }) {
    return LocalAnswersCompanion(
      attemptId: attemptId ?? this.attemptId,
      questionId: questionId ?? this.questionId,
      choice: choice ?? this.choice,
      flagged: flagged ?? this.flagged,
      timeMs: timeMs ?? this.timeMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (choice.present) {
      map['choice'] = Variable<String>(choice.value);
    }
    if (flagged.present) {
      map['flagged'] = Variable<bool>(flagged.value);
    }
    if (timeMs.present) {
      map['time_ms'] = Variable<int>(timeMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAnswersCompanion(')
          ..write('attemptId: $attemptId, ')
          ..write('questionId: $questionId, ')
          ..write('choice: $choice, ')
          ..write('flagged: $flagged, ')
          ..write('timeMs: $timeMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KvCacheTable extends KvCache with TableInfo<$KvCacheTable, KvCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>('key', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>('value', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv_cache';
  @override
  VerificationContext validateIntegrity(Insertable<KvCacheData> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KvCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvCacheData(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $KvCacheTable createAlias(String alias) {
    return $KvCacheTable(attachedDatabase, alias);
  }
}

class KvCacheData extends DataClass implements Insertable<KvCacheData> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const KvCacheData({required this.key, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  KvCacheCompanion toCompanion(bool nullToAbsent) {
    return KvCacheCompanion(key: Value(key), value: Value(value), updatedAt: Value(updatedAt));
  }

  factory KvCacheData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvCacheData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  KvCacheData copyWith({String? key, String? value, DateTime? updatedAt}) =>
      KvCacheData(key: key ?? this.key, value: value ?? this.value, updatedAt: updatedAt ?? this.updatedAt);
  KvCacheData copyWithCompanion(KvCacheCompanion data) {
    return KvCacheData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvCacheData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is KvCacheData && other.key == this.key && other.value == this.value && other.updatedAt == this.updatedAt);
}

class KvCacheCompanion extends UpdateCompanion<KvCacheData> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const KvCacheCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvCacheCompanion.insert({required String key, required String value, this.updatedAt = const Value.absent(), this.rowid = const Value.absent()})
    : key = Value(key),
      value = Value(value);
  static Insertable<KvCacheData> custom({Expression<String>? key, Expression<String>? value, Expression<DateTime>? updatedAt, Expression<int>? rowid}) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvCacheCompanion copyWith({Value<String>? key, Value<String>? value, Value<DateTime>? updatedAt, Value<int>? rowid}) {
    return KvCacheCompanion(key: key ?? this.key, value: value ?? this.value, updatedAt: updatedAt ?? this.updatedAt, rowid: rowid ?? this.rowid);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvCacheCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $CachedQuestionsTable cachedQuestions = $CachedQuestionsTable(this);
  late final $LocalAttemptsTable localAttempts = $LocalAttemptsTable(this);
  late final $LocalAnswersTable localAnswers = $LocalAnswersTable(this);
  late final $KvCacheTable kvCache = $KvCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedQuestions, localAttempts, localAnswers, kvCache];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('local_attempts', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('local_answers', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CachedQuestionsTableCreateCompanionBuilder = CachedQuestionsCompanion Function({
  required String id,
  required int examId,
  required int subjectId,
  required int year,
  Value<int?> number,
  required String body,
  required String optionsJson,
  required String answer,
  Value<String?> explanation,
  Value<String?> topic,
  Value<String?> imagePath,
  Value<String?> passageId,
  Value<String?> passageTitle,
  Value<String?> passageBody,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});
typedef $$CachedQuestionsTableUpdateCompanionBuilder = CachedQuestionsCompanion Function({
  Value<String> id,
  Value<int> examId,
  Value<int> subjectId,
  Value<int> year,
  Value<int?> number,
  Value<String> body,
  Value<String> optionsJson,
  Value<String> answer,
  Value<String?> explanation,
  Value<String?> topic,
  Value<String?> imagePath,
  Value<String?> passageId,
  Value<String?> passageTitle,
  Value<String?> passageBody,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CachedQuestionsTableFilterComposer extends Composer<_$AppDb, $CachedQuestionsTable> {
  $$CachedQuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get examId => $composableBuilder(column: $table.examId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get subjectId => $composableBuilder(column: $table.subjectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year => $composableBuilder(column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get number => $composableBuilder(column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get optionsJson => $composableBuilder(column: $table.optionsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get answer => $composableBuilder(column: $table.answer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get explanation => $composableBuilder(column: $table.explanation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get topic => $composableBuilder(column: $table.topic, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get passageId => $composableBuilder(column: $table.passageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get passageTitle => $composableBuilder(column: $table.passageTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get passageBody => $composableBuilder(column: $table.passageBody, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedQuestionsTableOrderingComposer extends Composer<_$AppDb, $CachedQuestionsTable> {
  $$CachedQuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get examId => $composableBuilder(column: $table.examId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get subjectId => $composableBuilder(column: $table.subjectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get year => $composableBuilder(column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get number => $composableBuilder(column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get optionsJson => $composableBuilder(column: $table.optionsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get answer => $composableBuilder(column: $table.answer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get explanation => $composableBuilder(column: $table.explanation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get topic => $composableBuilder(column: $table.topic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get passageId => $composableBuilder(column: $table.passageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get passageTitle => $composableBuilder(column: $table.passageTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get passageBody => $composableBuilder(column: $table.passageBody, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedQuestionsTableAnnotationComposer extends Composer<_$AppDb, $CachedQuestionsTable> {
  $$CachedQuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get examId => $composableBuilder(column: $table.examId, builder: (column) => column);

  GeneratedColumn<int> get subjectId => $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<int> get year => $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get number => $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get body => $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get optionsJson => $composableBuilder(column: $table.optionsJson, builder: (column) => column);

  GeneratedColumn<String> get answer => $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get explanation => $composableBuilder(column: $table.explanation, builder: (column) => column);

  GeneratedColumn<String> get topic => $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<String> get imagePath => $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get passageId => $composableBuilder(column: $table.passageId, builder: (column) => column);

  GeneratedColumn<String> get passageTitle => $composableBuilder(column: $table.passageTitle, builder: (column) => column);

  GeneratedColumn<String> get passageBody => $composableBuilder(column: $table.passageBody, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt => $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedQuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CachedQuestionsTable,
          CachedQuestion,
          $$CachedQuestionsTableFilterComposer,
          $$CachedQuestionsTableOrderingComposer,
          $$CachedQuestionsTableAnnotationComposer,
          $$CachedQuestionsTableCreateCompanionBuilder,
          $$CachedQuestionsTableUpdateCompanionBuilder,
          (CachedQuestion, BaseReferences<_$AppDb, $CachedQuestionsTable, CachedQuestion>),
          CachedQuestion,
          PrefetchHooks Function()
        > {
  $$CachedQuestionsTableTableManager(_$AppDb db, $CachedQuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CachedQuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CachedQuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CachedQuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> examId = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<int?> number = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> optionsJson = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String?> explanation = const Value.absent(),
                Value<String?> topic = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> passageId = const Value.absent(),
                Value<String?> passageTitle = const Value.absent(),
                Value<String?> passageBody = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedQuestionsCompanion(
                id: id,
                examId: examId,
                subjectId: subjectId,
                year: year,
                number: number,
                body: body,
                optionsJson: optionsJson,
                answer: answer,
                explanation: explanation,
                topic: topic,
                imagePath: imagePath,
                passageId: passageId,
                passageTitle: passageTitle,
                passageBody: passageBody,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int examId,
                required int subjectId,
                required int year,
                Value<int?> number = const Value.absent(),
                required String body,
                required String optionsJson,
                required String answer,
                Value<String?> explanation = const Value.absent(),
                Value<String?> topic = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> passageId = const Value.absent(),
                Value<String?> passageTitle = const Value.absent(),
                Value<String?> passageBody = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedQuestionsCompanion.insert(
                id: id,
                examId: examId,
                subjectId: subjectId,
                year: year,
                number: number,
                body: body,
                optionsJson: optionsJson,
                answer: answer,
                explanation: explanation,
                topic: topic,
                imagePath: imagePath,
                passageId: passageId,
                passageTitle: passageTitle,
                passageBody: passageBody,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable<$CachedQuestionsTable, CachedQuestion>(table), BaseReferences<_$AppDb, $CachedQuestionsTable, CachedQuestion>(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedQuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CachedQuestionsTable,
      CachedQuestion,
      $$CachedQuestionsTableFilterComposer,
      $$CachedQuestionsTableOrderingComposer,
      $$CachedQuestionsTableAnnotationComposer,
      $$CachedQuestionsTableCreateCompanionBuilder,
      $$CachedQuestionsTableUpdateCompanionBuilder,
      (CachedQuestion, BaseReferences<_$AppDb, $CachedQuestionsTable, CachedQuestion>),
      CachedQuestion,
      PrefetchHooks Function()
    >;
typedef $$LocalAttemptsTableCreateCompanionBuilder = LocalAttemptsCompanion Function({
  required String id,
  required int examId,
  required String examCode,
  required String mode,
  required String configJson,
  required String questionIdsJson,
  required int limitSeconds,
  Value<int> usedMs,
  Value<int> currentIndex,
  required DateTime startedAt,
  Value<DateTime?> submittedAt,
  Value<String?> clientScoreJson,
  Value<String?> serverScoreJson,
  Value<bool> synced,
  Value<int> rowid,
});
typedef $$LocalAttemptsTableUpdateCompanionBuilder = LocalAttemptsCompanion Function({
  Value<String> id,
  Value<int> examId,
  Value<String> examCode,
  Value<String> mode,
  Value<String> configJson,
  Value<String> questionIdsJson,
  Value<int> limitSeconds,
  Value<int> usedMs,
  Value<int> currentIndex,
  Value<DateTime> startedAt,
  Value<DateTime?> submittedAt,
  Value<String?> clientScoreJson,
  Value<String?> serverScoreJson,
  Value<bool> synced,
  Value<int> rowid,
});

final class $$LocalAttemptsTableReferences extends BaseReferences<_$AppDb, $LocalAttemptsTable, LocalAttempt> {
  $$LocalAttemptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalAnswersTable, List<LocalAnswer>> _localAnswersRefsTable(_$AppDb db) =>
      MultiTypedResultKey.fromTable(db.localAnswers, aliasName: 'local_attempts__id__local_answers__attempt_id');

  $$LocalAnswersTableProcessedTableManager get localAnswersRefs {
    final manager = $$LocalAnswersTableTableManager($_db, $_db.localAnswers).filter((f) => f.attemptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localAnswersRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$LocalAttemptsTableFilterComposer extends Composer<_$AppDb, $LocalAttemptsTable> {
  $$LocalAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get examId => $composableBuilder(column: $table.examId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get examCode => $composableBuilder(column: $table.examCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get configJson => $composableBuilder(column: $table.configJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get questionIdsJson => $composableBuilder(column: $table.questionIdsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get limitSeconds => $composableBuilder(column: $table.limitSeconds, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get usedMs => $composableBuilder(column: $table.usedMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentIndex => $composableBuilder(column: $table.currentIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get submittedAt => $composableBuilder(column: $table.submittedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientScoreJson => $composableBuilder(column: $table.clientScoreJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverScoreJson => $composableBuilder(column: $table.serverScoreJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(column: $table.synced, builder: (column) => ColumnFilters(column));

  Expression<bool> localAnswersRefs(Expression<bool> Function($$LocalAnswersTableFilterComposer f) f) {
    final $$LocalAnswersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localAnswers,
      getReferencedColumn: (t) => t.attemptId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$LocalAnswersTableFilterComposer(
        $db: $db,
        $table: $db.localAnswers,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return f(composer);
  }
}

class $$LocalAttemptsTableOrderingComposer extends Composer<_$AppDb, $LocalAttemptsTable> {
  $$LocalAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get examId => $composableBuilder(column: $table.examId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get examCode => $composableBuilder(column: $table.examCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get configJson => $composableBuilder(column: $table.configJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get questionIdsJson => $composableBuilder(column: $table.questionIdsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get limitSeconds => $composableBuilder(column: $table.limitSeconds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get usedMs => $composableBuilder(column: $table.usedMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentIndex => $composableBuilder(column: $table.currentIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get submittedAt => $composableBuilder(column: $table.submittedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientScoreJson => $composableBuilder(column: $table.clientScoreJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverScoreJson => $composableBuilder(column: $table.serverScoreJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$LocalAttemptsTableAnnotationComposer extends Composer<_$AppDb, $LocalAttemptsTable> {
  $$LocalAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get examId => $composableBuilder(column: $table.examId, builder: (column) => column);

  GeneratedColumn<String> get examCode => $composableBuilder(column: $table.examCode, builder: (column) => column);

  GeneratedColumn<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(column: $table.configJson, builder: (column) => column);

  GeneratedColumn<String> get questionIdsJson => $composableBuilder(column: $table.questionIdsJson, builder: (column) => column);

  GeneratedColumn<int> get limitSeconds => $composableBuilder(column: $table.limitSeconds, builder: (column) => column);

  GeneratedColumn<int> get usedMs => $composableBuilder(column: $table.usedMs, builder: (column) => column);

  GeneratedColumn<int> get currentIndex => $composableBuilder(column: $table.currentIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt => $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get submittedAt => $composableBuilder(column: $table.submittedAt, builder: (column) => column);

  GeneratedColumn<String> get clientScoreJson => $composableBuilder(column: $table.clientScoreJson, builder: (column) => column);

  GeneratedColumn<String> get serverScoreJson => $composableBuilder(column: $table.serverScoreJson, builder: (column) => column);

  GeneratedColumn<bool> get synced => $composableBuilder(column: $table.synced, builder: (column) => column);

  Expression<T> localAnswersRefs<T extends Object>(Expression<T> Function($$LocalAnswersTableAnnotationComposer a) f) {
    final $$LocalAnswersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localAnswers,
      getReferencedColumn: (t) => t.attemptId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$LocalAnswersTableAnnotationComposer(
        $db: $db,
        $table: $db.localAnswers,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return f(composer);
  }
}

class $$LocalAttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalAttemptsTable,
          LocalAttempt,
          $$LocalAttemptsTableFilterComposer,
          $$LocalAttemptsTableOrderingComposer,
          $$LocalAttemptsTableAnnotationComposer,
          $$LocalAttemptsTableCreateCompanionBuilder,
          $$LocalAttemptsTableUpdateCompanionBuilder,
          (LocalAttempt, $$LocalAttemptsTableReferences),
          LocalAttempt,
          PrefetchHooks Function({bool localAnswersRefs})
        > {
  $$LocalAttemptsTableTableManager(_$AppDb db, $LocalAttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalAttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> examId = const Value.absent(),
                Value<String> examCode = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<String> questionIdsJson = const Value.absent(),
                Value<int> limitSeconds = const Value.absent(),
                Value<int> usedMs = const Value.absent(),
                Value<int> currentIndex = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> submittedAt = const Value.absent(),
                Value<String?> clientScoreJson = const Value.absent(),
                Value<String?> serverScoreJson = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttemptsCompanion(
                id: id,
                examId: examId,
                examCode: examCode,
                mode: mode,
                configJson: configJson,
                questionIdsJson: questionIdsJson,
                limitSeconds: limitSeconds,
                usedMs: usedMs,
                currentIndex: currentIndex,
                startedAt: startedAt,
                submittedAt: submittedAt,
                clientScoreJson: clientScoreJson,
                serverScoreJson: serverScoreJson,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int examId,
                required String examCode,
                required String mode,
                required String configJson,
                required String questionIdsJson,
                required int limitSeconds,
                Value<int> usedMs = const Value.absent(),
                Value<int> currentIndex = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> submittedAt = const Value.absent(),
                Value<String?> clientScoreJson = const Value.absent(),
                Value<String?> serverScoreJson = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttemptsCompanion.insert(
                id: id,
                examId: examId,
                examCode: examCode,
                mode: mode,
                configJson: configJson,
                questionIdsJson: questionIdsJson,
                limitSeconds: limitSeconds,
                usedMs: usedMs,
                currentIndex: currentIndex,
                startedAt: startedAt,
                submittedAt: submittedAt,
                clientScoreJson: clientScoreJson,
                serverScoreJson: serverScoreJson,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<$LocalAttemptsTable, LocalAttempt>(table), $$LocalAttemptsTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({localAnswersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (localAnswersRefs) db.localAnswers],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localAnswersRefs)
                    await $_getPrefetchedDataByColumns<LocalAttempt, $LocalAttemptsTable, LocalAnswer, $LocalAnswersTable>(
                      currentTable: table,
                      referencedTable: $$LocalAttemptsTableReferences._localAnswersRefsTable(db),
                      managerFromTypedResult: (p0) => $$LocalAttemptsTableReferences(db, table, p0).localAnswersRefs,
                      currentColumn: 'id',
                      referencedColumn: 'attempt_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalAttemptsTable,
      LocalAttempt,
      $$LocalAttemptsTableFilterComposer,
      $$LocalAttemptsTableOrderingComposer,
      $$LocalAttemptsTableAnnotationComposer,
      $$LocalAttemptsTableCreateCompanionBuilder,
      $$LocalAttemptsTableUpdateCompanionBuilder,
      (LocalAttempt, $$LocalAttemptsTableReferences),
      LocalAttempt,
      PrefetchHooks Function({bool localAnswersRefs})
    >;
typedef $$LocalAnswersTableCreateCompanionBuilder = LocalAnswersCompanion Function({
  required String attemptId,
  required String questionId,
  Value<String?> choice,
  Value<bool> flagged,
  Value<int> timeMs,
  Value<int> rowid,
});
typedef $$LocalAnswersTableUpdateCompanionBuilder = LocalAnswersCompanion Function({
  Value<String> attemptId,
  Value<String> questionId,
  Value<String?> choice,
  Value<bool> flagged,
  Value<int> timeMs,
  Value<int> rowid,
});

final class $$LocalAnswersTableReferences extends BaseReferences<_$AppDb, $LocalAnswersTable, LocalAnswer> {
  $$LocalAnswersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocalAttemptsTable _attemptIdTable(_$AppDb db) => db.localAttempts.createAlias('local_answers__attempt_id__local_attempts__id');

  $$LocalAttemptsTableProcessedTableManager get attemptId {
    final $_column = $_itemColumn<String>('attempt_id')!;

    final manager = $$LocalAttemptsTableTableManager($_db, $_db.localAttempts).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attemptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$LocalAnswersTableFilterComposer extends Composer<_$AppDb, $LocalAnswersTable> {
  $$LocalAnswersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get questionId => $composableBuilder(column: $table.questionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get choice => $composableBuilder(column: $table.choice, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get flagged => $composableBuilder(column: $table.flagged, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timeMs => $composableBuilder(column: $table.timeMs, builder: (column) => ColumnFilters(column));

  $$LocalAttemptsTableFilterComposer get attemptId {
    final $$LocalAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.localAttempts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$LocalAttemptsTableFilterComposer(
        $db: $db,
        $table: $db.localAttempts,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }
}

class $$LocalAnswersTableOrderingComposer extends Composer<_$AppDb, $LocalAnswersTable> {
  $$LocalAnswersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get questionId => $composableBuilder(column: $table.questionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get choice => $composableBuilder(column: $table.choice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get flagged => $composableBuilder(column: $table.flagged, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timeMs => $composableBuilder(column: $table.timeMs, builder: (column) => ColumnOrderings(column));

  $$LocalAttemptsTableOrderingComposer get attemptId {
    final $$LocalAttemptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.localAttempts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$LocalAttemptsTableOrderingComposer(
        $db: $db,
        $table: $db.localAttempts,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }
}

class $$LocalAnswersTableAnnotationComposer extends Composer<_$AppDb, $LocalAnswersTable> {
  $$LocalAnswersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get questionId => $composableBuilder(column: $table.questionId, builder: (column) => column);

  GeneratedColumn<String> get choice => $composableBuilder(column: $table.choice, builder: (column) => column);

  GeneratedColumn<bool> get flagged => $composableBuilder(column: $table.flagged, builder: (column) => column);

  GeneratedColumn<int> get timeMs => $composableBuilder(column: $table.timeMs, builder: (column) => column);

  $$LocalAttemptsTableAnnotationComposer get attemptId {
    final $$LocalAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.localAttempts,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) => $$LocalAttemptsTableAnnotationComposer(
        $db: $db,
        $table: $db.localAttempts,
        $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
        joinBuilder: joinBuilder,
        $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
      ),
    );
    return composer;
  }
}

class $$LocalAnswersTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalAnswersTable,
          LocalAnswer,
          $$LocalAnswersTableFilterComposer,
          $$LocalAnswersTableOrderingComposer,
          $$LocalAnswersTableAnnotationComposer,
          $$LocalAnswersTableCreateCompanionBuilder,
          $$LocalAnswersTableUpdateCompanionBuilder,
          (LocalAnswer, $$LocalAnswersTableReferences),
          LocalAnswer,
          PrefetchHooks Function({bool attemptId})
        > {
  $$LocalAnswersTableTableManager(_$AppDb db, $LocalAnswersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalAnswersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalAnswersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalAnswersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> attemptId = const Value.absent(),
            Value<String> questionId = const Value.absent(),
            Value<String?> choice = const Value.absent(),
            Value<bool> flagged = const Value.absent(),
            Value<int> timeMs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalAnswersCompanion(attemptId: attemptId, questionId: questionId, choice: choice, flagged: flagged, timeMs: timeMs, rowid: rowid),
          createCompanionCallback: ({
            required String attemptId,
            required String questionId,
            Value<String?> choice = const Value.absent(),
            Value<bool> flagged = const Value.absent(),
            Value<int> timeMs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalAnswersCompanion.insert(attemptId: attemptId, questionId: questionId, choice: choice, flagged: flagged, timeMs: timeMs, rowid: rowid),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<$LocalAnswersTable, LocalAnswer>(table), $$LocalAnswersTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({attemptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <T extends TableManagerState<dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic, dynamic>>(state) {
                    if (attemptId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.attemptId,
                        referencedTable: $$LocalAnswersTableReferences._attemptIdTable(db),
                        referencedColumn: $$LocalAnswersTableReferences._attemptIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalAnswersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalAnswersTable,
      LocalAnswer,
      $$LocalAnswersTableFilterComposer,
      $$LocalAnswersTableOrderingComposer,
      $$LocalAnswersTableAnnotationComposer,
      $$LocalAnswersTableCreateCompanionBuilder,
      $$LocalAnswersTableUpdateCompanionBuilder,
      (LocalAnswer, $$LocalAnswersTableReferences),
      LocalAnswer,
      PrefetchHooks Function({bool attemptId})
    >;
typedef $$KvCacheTableCreateCompanionBuilder = KvCacheCompanion Function({
  required String key,
  required String value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$KvCacheTableUpdateCompanionBuilder = KvCacheCompanion Function({Value<String> key, Value<String> value, Value<DateTime> updatedAt, Value<int> rowid});

class $$KvCacheTableFilterComposer extends Composer<_$AppDb, $KvCacheTable> {
  $$KvCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$KvCacheTableOrderingComposer extends Composer<_$AppDb, $KvCacheTable> {
  $$KvCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$KvCacheTableAnnotationComposer extends Composer<_$AppDb, $KvCacheTable> {
  $$KvCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$KvCacheTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $KvCacheTable,
          KvCacheData,
          $$KvCacheTableFilterComposer,
          $$KvCacheTableOrderingComposer,
          $$KvCacheTableAnnotationComposer,
          $$KvCacheTableCreateCompanionBuilder,
          $$KvCacheTableUpdateCompanionBuilder,
          (KvCacheData, BaseReferences<_$AppDb, $KvCacheTable, KvCacheData>),
          KvCacheData,
          PrefetchHooks Function()
        > {
  $$KvCacheTableTableManager(_$AppDb db, $KvCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$KvCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$KvCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$KvCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => KvCacheCompanion(key: key, value: value, updatedAt: updatedAt, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => KvCacheCompanion.insert(key: key, value: value, updatedAt: updatedAt, rowid: rowid),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<$KvCacheTable, KvCacheData>(table), BaseReferences<_$AppDb, $KvCacheTable, KvCacheData>(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KvCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $KvCacheTable,
      KvCacheData,
      $$KvCacheTableFilterComposer,
      $$KvCacheTableOrderingComposer,
      $$KvCacheTableAnnotationComposer,
      $$KvCacheTableCreateCompanionBuilder,
      $$KvCacheTableUpdateCompanionBuilder,
      (KvCacheData, BaseReferences<_$AppDb, $KvCacheTable, KvCacheData>),
      KvCacheData,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$CachedQuestionsTableTableManager get cachedQuestions => $$CachedQuestionsTableTableManager(_db, _db.cachedQuestions);
  $$LocalAttemptsTableTableManager get localAttempts => $$LocalAttemptsTableTableManager(_db, _db.localAttempts);
  $$LocalAnswersTableTableManager get localAnswers => $$LocalAnswersTableTableManager(_db, _db.localAnswers);
  $$KvCacheTableTableManager get kvCache => $$KvCacheTableTableManager(_db, _db.kvCache);
}
