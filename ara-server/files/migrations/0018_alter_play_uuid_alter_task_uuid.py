# OSISM downstream replacement for ARA's stock migration 0018.
#
# Stock 0018 issues a bare `ALTER TABLE ... MODIFY uuid char(32)`, which fails on
# a populated MariaDB whose plays.uuid/tasks.uuid are native `uuid` columns: the
# 36-char dashed render overflows char(32) -> DataError 1406. This version
# normalizes the existing MariaDB data in place before the column shrinks, so ARA
# history is preserved. On a fresh DB and on non-MySQL backends it is
# behavior-identical to stock. Background: ARA issues #617 and #628
# (https://codeberg.org/ansible-community/ara/issues/628).
from django.db import migrations
import ara.api.models


def normalize_mysql_uuids(apps, schema_editor):
    # Only MariaDB/MySQL stored pre-1.7.4 UUIDs as native `uuid` columns.
    if schema_editor.connection.vendor != "mysql":
        return
    quote = schema_editor.quote_name
    play = quote(apps.get_model("api", "Play")._meta.db_table)
    task = quote(apps.get_model("api", "Task")._meta.db_table)
    col = quote("uuid")
    with schema_editor.connection.cursor() as cursor:
        # widen native uuid -> char(36) so the dashed render fits, then de-dash
        cursor.execute(f"ALTER TABLE {play} MODIFY {col} char(36) NOT NULL")
        cursor.execute(f"UPDATE {play} SET {col} = REPLACE({col}, '-', '')")
        cursor.execute(f"ALTER TABLE {task} MODIFY {col} char(36) NULL")
        cursor.execute(f"UPDATE {task} SET {col} = REPLACE({col}, '-', '') WHERE {col} IS NOT NULL")


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0017_optional_playbook_controller"),
    ]

    operations = [
        # Reverse is intentionally a no-op: the forward de-dash is not re-applied
        # on rollback (these ARA migrations are forward-only in practice).
        migrations.RunPython(normalize_mysql_uuids, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="play",
            name="uuid",
            field=ara.api.models.Char32UUIDField(),
        ),
        migrations.AlterField(
            model_name="task",
            name="uuid",
            field=ara.api.models.Char32UUIDField(null=True),
        ),
    ]
