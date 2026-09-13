from __future__ import annotations

from datetime import datetime
from uuid import UUID

from ninja import Schema


class ChecklistItemSchema(Schema):
    id: UUID
    text: str
    is_completed: bool = False


# --- Boards ---

class BoardOut(Schema):
    id: UUID
    user_id: str  # Identity Platform UID
    title: str
    background_color: str
    background_layout: str
    created_at: datetime
    updated_at: datetime


class BoardUpdateIn(Schema):
    title: str | None = None
    background_color: str | None = None
    background_layout: str | None = None


# --- Notes ---

class NoteOut(Schema):
    id: UUID
    board_id: UUID
    user_id: str  # Identity Platform UID
    content_text: str | None
    content_drawing: str | None  # base64
    color: str
    pos_x: float
    pos_y: float
    z_index: int
    template: str
    checklist_items: list[ChecklistItemSchema]
    created_at: datetime
    updated_at: datetime


class NoteUpsertIn(Schema):
    board_id: UUID
    content_text: str | None = None
    content_drawing: str | None = None  # base64
    color: str
    pos_x: float
    pos_y: float
    z_index: int
    template: str = "plain"
    checklist_items: list[ChecklistItemSchema] = []


# --- Profile ---

class ProfileOut(Schema):
    settings: dict


class ProfileUpsertIn(Schema):
    settings: dict


# --- RPC ---

class MatchNotesIn(Schema):
    board_uuid: UUID


class MatchNoteResult(Schema):
    id: UUID
    new_x: float
    new_y: float
