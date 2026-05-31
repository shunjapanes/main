#!/usr/bin/env python3
"""
Googleカレンダーのプライベートイベントのうち、他のイベントと重複しているものを削除するスクリプト。

重複の判定基準:
- 同じタイトル (summary)
- 同じ開始日時 (start)
- 同じ終了日時 (end)
- 片方が private、もう片方が非 private（または別カレンダーに同内容がある）

使い方:
  pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib
  python delete_private_duplicates.py

初回実行時にブラウザで Google アカウントの認証を求められます。
credentials.json を Google Cloud Console からダウンロードして同ディレクトリに置いてください。
"""

import os
import json
from collections import defaultdict
from datetime import datetime, timezone

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/calendar"]
TOKEN_FILE = "token.json"
CREDENTIALS_FILE = "credentials.json"


def get_credentials():
    creds = None
    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        with open(TOKEN_FILE, "w") as f:
            f.write(creds.to_json())
    return creds


def normalize_time(t: dict) -> str:
    """'dateTime' か 'date' を統一した文字列に変換する。"""
    return t.get("dateTime") or t.get("date") or ""


def event_key(event: dict) -> tuple:
    """重複判定用のキー: (タイトル, 開始, 終了)"""
    summary = event.get("summary", "").strip()
    start = normalize_time(event.get("start", {}))
    end = normalize_time(event.get("end", {}))
    return (summary, start, end)


def is_private(event: dict) -> bool:
    return event.get("visibility") == "private"


def fetch_all_events(service, calendar_id: str = "primary") -> list:
    events = []
    page_token = None
    while True:
        resp = service.events().list(
            calendarId=calendar_id,
            maxResults=2500,
            singleEvents=True,
            orderBy="startTime",
            timeMin="2000-01-01T00:00:00Z",
            pageToken=page_token,
        ).execute()
        events.extend(resp.get("items", []))
        page_token = resp.get("nextPageToken")
        if not page_token:
            break
    return events


def find_private_duplicates(events: list) -> list:
    """
    同じキーを持つイベントのグループを探し、
    非プライベートのイベントと重複しているプライベートイベントを返す。
    """
    groups = defaultdict(list)
    for ev in events:
        # キャンセル済みは除外
        if ev.get("status") == "cancelled":
            continue
        key = event_key(ev)
        if key[0] == "" and key[1] == "":
            # タイトルも日時も不明なイベントはスキップ
            continue
        groups[key].append(ev)

    to_delete = []
    for key, group in groups.items():
        if len(group) < 2:
            continue
        private_events = [e for e in group if is_private(e)]
        non_private_events = [e for e in group if not is_private(e)]
        # 非プライベートが存在する場合のみ、プライベートを削除対象とする
        if private_events and non_private_events:
            to_delete.extend(private_events)

    return to_delete


def delete_events(service, events: list, calendar_id: str = "primary", dry_run: bool = True):
    if not events:
        print("削除対象のイベントはありませんでした。")
        return

    print(f"\n{'[DRY RUN] ' if dry_run else ''}削除対象イベント ({len(events)} 件):")
    for ev in events:
        start = normalize_time(ev.get("start", {}))
        print(f"  - [{ev['id']}] {ev.get('summary', '(タイトルなし)')} / {start}")

    if dry_run:
        print("\n--dry-run モードのため実際には削除しません。")
        print("本当に削除するには dry_run=False にして実行してください。")
        return

    print("\n削除を開始します...")
    deleted = 0
    for ev in events:
        try:
            service.events().delete(calendarId=calendar_id, eventId=ev["id"]).execute()
            print(f"  削除: {ev.get('summary', '(タイトルなし)')} [{ev['id']}]")
            deleted += 1
        except Exception as e:
            print(f"  エラー ({ev['id']}): {e}")

    print(f"\n完了: {deleted}/{len(events)} 件削除しました。")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Googleカレンダーのプライベート重複イベントを削除する")
    parser.add_argument(
        "--calendar-id",
        default="primary",
        help="対象カレンダーID (デフォルト: primary)",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="このフラグを付けると実際に削除します（省略時は dry-run）",
    )
    args = parser.parse_args()

    print("Google Calendar に接続中...")
    creds = get_credentials()
    service = build("calendar", "v3", credentials=creds)

    print(f"イベントを取得中 (calendar: {args.calendar_id}) ...")
    events = fetch_all_events(service, args.calendar_id)
    print(f"  取得件数: {len(events)} 件")

    duplicates = find_private_duplicates(events)
    delete_events(service, duplicates, args.calendar_id, dry_run=not args.execute)


if __name__ == "__main__":
    main()
