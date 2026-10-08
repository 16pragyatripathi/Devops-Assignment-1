"""create books table

Revision ID: 0001_create_books
"""
import sqlalchemy as sa
from alembic import op

revision = "0001_create_books"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "books",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("author", sa.String(length=120), nullable=False),
        sa.Column("category", sa.String(length=40), nullable=False, server_default="GENERAL"),
        sa.Column("total_copies", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("available_copies", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade():
    op.drop_table("books")
