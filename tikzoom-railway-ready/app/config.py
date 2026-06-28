"""Configuration loaded from environment variables and persisted DB settings.
​
Values fall back to hard-coded defaults so the app works on Railway even
without a .env file present (Railway env vars still override these).
"""
from __future__ import annotations
​
import os
from functools import lru_cache
from pathlib import Path
​
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict
​
# Resolve .env relative to the project root (parent of the `app/` package)
# so it loads correctly regardless of the current working directory.
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
_ENV_FILE = _PROJECT_ROOT / ".env"
​
# Eagerly load .env into os.environ as a safety net (if it exists).
if _ENV_FILE.exists():
    try:
        for _line in _ENV_FILE.read_text(encoding="utf-8").splitlines():
            _line = _line.strip()
            if not _line or _line.startswith("#") or "=" not in _line:
                continue
            _k, _, _v = _line.partition("=")
            _k = _k.strip()
            _v = _v.strip().strip('"').strip("'")
            os.environ.setdefault(_k, _v)
    except OSError:
        pass
​
# Hard-coded fallbacks so the app works on Railway with zero configuration.
# Real Railway/.env values always override these via os.environ.setdefault().
_DEFAULTS = {
    "BOT_TOKEN": "8633510294:AAF47_jGJyVGdfNdxljD76CdOHl_swbevN4",
    "ADMIN_IDS": "6472365461",
    "WEBHOOK_SECRET": "1c2b36206d15393b0c73e98a68781c453dea5414a1db2a6e52ba183634d990d7",
    "FERNET_KEY": "SyD-ABw3_ZjPOCq8DFSj4M7AfkrQ1Erg1BRCthFQqww=",
    "DATA_DIR": "/data",
    "DB_PATH": "/data/platform.db",
    "BOTS_DIR": "/data/bots_storage",
    "DEFAULT_LANG": "ar",
}
for _k, _v in _DEFAULTS.items():
    os.environ.setdefault(_k, _v)
​
​
class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=str(_ENV_FILE), env_file_encoding="utf-8", extra="ignore")
​
    bot_token: str = Field(default="8633510294:AAF47_jGJyVGdfNdxljD76CdOHl_swbevN4", alias="BOT_TOKEN")
    admin_ids: str = Field(default="6472365461", alias="ADMIN_IDS")
    public_base_url: str = Field(default="https://localhost", alias="PUBLIC_BASE_URL")
    force_sub_channels: str = Field(default="", alias="FORCE_SUB_CHANNELS")
    webhook_secret: str = Field(default="1c2b36206d15393b0c73e98a68781c453dea5414a1db2a6e52ba183634d990d7", alias="WEBHOOK_SECRET")
    fernet_key: str = Field(default="SyD-ABw3_ZjPOCq8DFSj4M7AfkrQ1Erg1BRCthFQqww=", alias="FERNET_KEY")
    host: str = Field(default="0.0.0.0", alias="HOST")
    port: int = Field(default=8000, alias="PORT")
    hosted_port_start: int = Field(default=18000, alias="HOSTED_PORT_START")
    hosted_port_end: int = Field(default=18999, alias="HOSTED_PORT_END")
    data_dir: str = Field(default="/data", alias="DATA_DIR")
    bots_dir: str = Field(default="/data/bots_storage", alias="BOTS_DIR")
    db_path: str = Field(default="/data/platform.db", alias="DB_PATH")
    default_lang: str = Field(default="ar", alias="DEFAULT_LANG")
    api_docs_url: str = Field(
        default="https://api-docs-wkuicuhe.devinapps.com/",
        alias="API_DOCS_URL",
    )
​
    @property
    def admin_id_list(self) -> list[int]:
        return [int(x) for x in self.admin_ids.split(",") if x.strip().isdigit()]
​
    @property
    def force_sub_list(self) -> list[str]:
        return [c.strip().lstrip("@") for c in self.force_sub_channels.split(",") if c.strip()]
​
    @property
    def data_path(self) -> Path:
        p = Path(self.data_dir).resolve()
        p.mkdir(parents=True, exist_ok=True)
        return p
​
    @property
    def bots_path(self) -> Path:
        p = Path(self.bots_dir).resolve()
        p.mkdir(parents=True, exist_ok=True)
        return p
​
    @property
    def db_url(self) -> str:
        p = Path(self.db_path).resolve()
        p.parent.mkdir(parents=True, exist_ok=True)
        return f"sqlite+aiosqlite:///{p}"
​
​
@lru_cache
def get_settings() -> Settings:
    return Settings()
​
