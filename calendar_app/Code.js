/**
 * カレンダーから予定を取得するGASアプリケーション
 * 
 * このアプリケーションは指定されたカレンダーから特定期間の予定を取得し
 * JSON形式で返すWebアプリケーションです。
 */

// Webアプリケーションとして公開するためのdoGet関数
function doGet(e) {
  try {
    // アクションパラメータを取得
    const action = e.parameter.action || 'events'; // デフォルトはイベント取得
    
    // アクションに応じて処理を分岐
    switch (action) {
      case 'calendars':
        return getCalendarsList(e);
      case 'events':
      default:
        return getEventsResponse(e);
    }
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      error: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * カレンダーイベントを取得して結果を返す関数
 */
function getEventsResponse(e) {
  // パラメータを取得
  const calendarId = e.parameter.calendarId || 'primary'; // デフォルトは主要カレンダー
  const days = parseInt(e.parameter.days || '7', 10); // デフォルトは7日間
  const startDate = e.parameter.startDate ? new Date(e.parameter.startDate) : new Date(); // 開始日（デフォルトは今日）
  const searchQuery = e.parameter.q || ''; // 検索クエリ（空なら全ての予定）
  
  // カレンダーIDが複数ある場合（カンマ区切り）
  const calendarIds = calendarId.split(',');
  
  // 複数のカレンダーの予定を取得し、結合する
  let allEvents = [];
  calendarIds.forEach(id => {
    const events = getCalendarEvents(id.trim(), startDate, days, searchQuery);
    allEvents = allEvents.concat(events);
  });
  
  // イベントを開始時間順にソート
  allEvents.sort((a, b) => {
    const dateA = new Date(a.startTime);
    const dateB = new Date(b.startTime);
    return dateA - dateB;
  });
  
  // 結果をJSONで返す
  return ContentService.createTextOutput(JSON.stringify({
    events: allEvents,
    count: allEvents.length,
    query: searchQuery ? searchQuery : 'なし',
    periodStart: startDate.toISOString(),
    periodEnd: new Date(startDate.getTime() + days * 24 * 60 * 60 * 1000).toISOString(),
    calendars: calendarIds
  })).setMimeType(ContentService.MimeType.JSON);
}

/**
 * カレンダーリストを取得する関数
 */
function getCalendarsList(e) {
  const calendars = getAllCalendars();
  
  // JSONで返す
  return ContentService.createTextOutput(JSON.stringify({
    calendars: calendars,
    count: calendars.length
  })).setMimeType(ContentService.MimeType.JSON);
}

/**
 * カレンダーから指定期間の予定を取得する関数
 * 
 * @param {string} calendarId - カレンダーID（例: 'primary', またはメールアドレスなど）
 * @param {Date} startDate - 取得開始日
 * @param {number} days - 取得する日数
 * @param {string} searchQuery - 検索クエリ（タイトルや説明に含まれるテキスト）
 * @return {Object[]} イベントの配列
 */
function getCalendarEvents(calendarId, startDate, days, searchQuery = '') {
  // 終了日を計算
  const endDate = new Date(startDate);
  endDate.setDate(startDate.getDate() + days);
  
  // 日付をISOフォーマットに変換
  const timeMin = startDate.toISOString();
  const timeMax = endDate.toISOString();
  
  // APIパラメータ
  const params = {
    timeMin: timeMin,
    timeMax: timeMax,
    singleEvents: true,
    orderBy: 'startTime',
    maxResults: 2500 // 最大取得件数
  };
  
  // 検索クエリがあれば追加
  if (searchQuery) {
    params.q = searchQuery;
  }
  
  try {
    // カレンダーAPIで予定を取得
    const events = Calendar.Events.list(calendarId, params);
    
    // カレンダー名を取得
    const calendarName = getCalendarName(calendarId);
    
    // 必要な情報だけを抽出して返す
    return events.items.map(event => {
      // 開始時間と終了時間を取得
      let startTime, endTime, allDay = false;
      
      if (event.start.date) {
        // 終日イベントの場合
        startTime = event.start.date;
        endTime = event.end.date;
        allDay = true;
      } else {
        // 時間指定イベントの場合
        startTime = event.start.dateTime;
        endTime = event.end.dateTime;
      }
      
      // 返すイベント情報
      return {
        id: event.id,
        title: event.summary || '(タイトルなし)',
        description: event.description || '',
        location: event.location || '',
        startTime: startTime,
        endTime: endTime,
        allDay: allDay,
        creator: event.creator ? event.creator.email : '',
        attendees: event.attendees ? event.attendees.map(a => a.email) : [],
        status: event.status || 'confirmed',
        htmlLink: event.htmlLink || '',
        calendarId: calendarId,
        calendarName: calendarName,
        colorId: event.colorId || ''
      };
    });
  } catch (error) {
    console.error(`カレンダー ${calendarId} からのイベント取得中にエラーが発生しました: ${error}`);
    return []; // エラー時は空配列を返す
  }
}

/**
 * カレンダーIDからカレンダー名を取得する関数
 * 
 * @param {string} calendarId - カレンダーID
 * @return {string} カレンダー名
 */
function getCalendarName(calendarId) {
  try {
    if (calendarId === 'primary') {
      return '主要カレンダー';
    }
    
    const calendar = Calendar.Calendars.get(calendarId);
    return calendar.summary || calendarId;
  } catch (error) {
    console.error(`カレンダー名の取得エラー (${calendarId}): ${error}`);
    return calendarId; // エラー時はIDをそのまま返す
  }
}

/**
 * 利用可能なすべてのカレンダーリストを取得する関数
 */
function getAllCalendars() {
  try {
    // 自分のカレンダーリストを取得
    const calendars = Calendar.CalendarList.list();
    
    // 必要な情報だけ抽出
    const calendarList = calendars.items.map(cal => {
      return {
        id: cal.id,
        name: cal.summary,
        description: cal.description || '',
        primary: cal.primary || false,
        accessRole: cal.accessRole || '',
        backgroundColor: cal.backgroundColor || '',
        foregroundColor: cal.foregroundColor || ''
      };
    });
    
    return calendarList;
  } catch (error) {
    console.error(`カレンダーリスト取得エラー: ${error}`);
    return [];
  }
}

/**
 * Claspで直接実行するための関数
 * 引数は必要に応じて設定してください
 */
function getEvents() {
  const params = {
    calendarId: 'primary',
    days: 7,
    startDate: new Date(),
    searchQuery: ''
  };
  
  // 現在の日時をセット
  const startDate = params.startDate;
  const days = params.days;
  
  // 予定を取得
  const events = getCalendarEvents(params.calendarId, startDate, days, params.searchQuery);
  
  // ログに出力（実行結果を確認するため）
  Logger.log(JSON.stringify({
    events: events,
    count: events.length,
    periodStart: startDate.toISOString(),
    periodEnd: new Date(startDate.getTime() + days * 24 * 60 * 60 * 1000).toISOString(),
    calendarId: params.calendarId
  }, null, 2));
  
  return events;
}

/**
 * 特定の日付範囲の予定を取得するための関数
 * clasp runで実行することを想定しています
 * 
 * @param {string} calendarId - カレンダーID
 * @param {number} days - 取得する日数
 * @param {string} startDateStr - 開始日 (YYYY-MM-DD形式)
 * @param {string} query - 検索クエリ
 */
function getCalendarEventsWithParams(calendarId, days, startDateStr, query) {
  // パラメータの設定
  calendarId = calendarId || 'primary';
  days = parseInt(days, 10) || 7;
  const startDate = startDateStr ? new Date(startDateStr) : new Date();
  query = query || '';
  
  // 予定を取得
  const events = getCalendarEvents(calendarId, startDate, days, query);
  
  // 結果をログに出力
  Logger.log(JSON.stringify({
    events: events,
    count: events.length,
    query: query ? query : 'なし',
    periodStart: startDate.toISOString(),
    periodEnd: new Date(startDate.getTime() + days * 24 * 60 * 60 * 1000).toISOString(),
    calendarId: calendarId
  }, null, 2));
  
  return events;
}

/**
 * 明日の予定だけを取得する関数
 */
function getTomorrowEvents() {
  // 明日の日付を取得
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  // 日付を年月日のみにリセット（時刻は00:00:00に）
  tomorrow.setHours(0, 0, 0, 0);
  
  // 終了日は明日の終了時刻
  const tomorrowEnd = new Date(tomorrow);
  tomorrowEnd.setHours(23, 59, 59, 999);
  
  // 予定を取得
  const calendarId = 'primary';
  const events = getCalendarEvents(calendarId, tomorrow, 1, '');
  
  // 明日の予定だけにフィルタリング
  const tomorrowOnly = events.filter(event => {
    const eventDate = new Date(event.startTime);
    return eventDate >= tomorrow && eventDate <= tomorrowEnd;
  });
  
  // ログに出力
  Logger.log(JSON.stringify({
    events: tomorrowOnly,
    count: tomorrowOnly.length,
    tomorrowDate: tomorrow.toISOString(),
    calendarId: calendarId
  }, null, 2));
  
  return tomorrowOnly;
}

/**
 * 今日から3日間の予定を取得する関数
 */
function getNextThreeDaysEvents() {
  // 今日の日付
  const today = new Date();
  
  // 3日間の予定を取得
  const calendarId = 'primary';
  const events = getCalendarEvents(calendarId, today, 3, '');
  
  // ログに出力
  Logger.log(JSON.stringify({
    events: events,
    count: events.length,
    periodStart: today.toISOString(),
    periodEnd: new Date(today.getTime() + 3 * 24 * 60 * 60 * 1000).toISOString(),
    calendarId: calendarId
  }, null, 2));
  
  return events;
}

/**
 * 特定の日付の予定を取得する関数
 * 任意の年月日を指定して、その日の予定を取得します
 * 日本時間で指定された日付の00:00から23:59までの予定を正確に取得します
 * 
 * @param {string|Date} targetDate - 取得したい日付（Date型、または 'YYYY-MM-DD' 形式の文字列）
 * @param {string} calendarId - カレンダーID（デフォルト: 'primary'）
 * @return {Object[]} イベントの配列
 */
function getDateEvents(targetDate, calendarId = 'primary') {
  // 日付の正規化（文字列の場合はDate型に変換）
  let dateObj;
  if (typeof targetDate === 'string') {
    // YYYY-MM-DD形式の文字列を日本時間の日付として解釈
    const parts = targetDate.split('-');
    if (parts.length === 3) {
      const year = parseInt(parts[0], 10);
      const month = parseInt(parts[1], 10) - 1; // 月は0-11で表現
      const day = parseInt(parts[2], 10);
      // 日本時間の0時0分0秒を設定
      dateObj = new Date(year, month, day, 0, 0, 0);
    } else {
      dateObj = new Date(targetDate);
    }
  } else if (targetDate instanceof Date) {
    dateObj = new Date(targetDate);
    // 時間をその日の始まりにリセット
    dateObj.setHours(0, 0, 0, 0);
  } else {
    dateObj = new Date(); // デフォルトは今日
    dateObj.setHours(0, 0, 0, 0);
  }
  
  // 日付が不正な場合のエラーチェック
  if (isNaN(dateObj.getTime())) {
    console.error('不正な日付形式です。YYYY-MM-DD形式、または有効なDate型で指定してください');
    return [];
  }
  
  // 指定日の23:59:59まで
  const endDate = new Date(dateObj);
  endDate.setHours(23, 59, 59, 999);
  
  // デバッグ用に日付情報をログ出力
  Logger.log("指定日付（開始）: " + dateObj.toLocaleString('ja-JP'));
  Logger.log("指定日付（終了）: " + endDate.toLocaleString('ja-JP'));
  Logger.log("ISO形式（開始）: " + dateObj.toISOString());
  Logger.log("ISO形式（終了）: " + endDate.toISOString());
  
  // APIパラメータを設定
  const params = {
    timeMin: dateObj.toISOString(),
    timeMax: endDate.toISOString(),
    singleEvents: true,
    orderBy: 'startTime',
    maxResults: 2500
  };
  
  try {
    // カレンダーAPIで直接指定日の予定を取得
    const eventsResult = Calendar.Events.list(calendarId, params);
    
    // カレンダー名を取得
    const calendarName = getCalendarName(calendarId);
    
    // 必要な情報だけを抽出
    const dateEvents = eventsResult.items.map(event => {
      // 開始時間と終了時間を取得
      let startTime, endTime, allDay = false;
      
      if (event.start.date) {
        // 終日イベントの場合
        startTime = event.start.date;
        endTime = event.end.date;
        allDay = true;
      } else {
        // 時間指定イベントの場合
        startTime = event.start.dateTime;
        endTime = event.end.dateTime;
      }
      
      return {
        id: event.id,
        title: event.summary || '(タイトルなし)',
        description: event.description || '',
        location: event.location || '',
        startTime: startTime,
        endTime: endTime,
        allDay: allDay,
        creator: event.creator ? event.creator.email : '',
        attendees: event.attendees ? event.attendees.map(a => a.email) : [],
        status: event.status || 'confirmed',
        htmlLink: event.htmlLink || '',
        calendarId: calendarId,
        calendarName: calendarName,
        colorId: event.colorId || ''
      };
    });
    
    // 指定日のイベントのみをフィルタリング（日本時間での同日判定）
    const filteredEvents = dateEvents.filter(event => {
      // 開始時間を日本時間のDateオブジェクトとして解釈
      const eventStartTime = new Date(event.startTime);
      const eventDate = eventStartTime.getDate();
      const eventMonth = eventStartTime.getMonth();
      const eventYear = eventStartTime.getFullYear();
      
      // 指定日の年月日を取得
      const targetDay = dateObj.getDate();
      const targetMonth = dateObj.getMonth();
      const targetYear = dateObj.getFullYear();
      
      // 同じ日付かどうかを判定
      return eventYear === targetYear && eventMonth === targetMonth && eventDate === targetDay;
    });
    
    // ログに出力
    Logger.log(JSON.stringify({
      events: filteredEvents,
      count: filteredEvents.length,
      targetDate: dateObj.toLocaleString('ja-JP'),
      calendarId: calendarId
    }, null, 2));
    
    return filteredEvents;
  } catch (error) {
    console.error(`指定日の予定取得中にエラーが発生しました: ${error}`);
    Logger.log(`指定日の予定取得中にエラーが発生しました: ${error}`);
    return []; // エラー時は空配列を返す
  }
} 