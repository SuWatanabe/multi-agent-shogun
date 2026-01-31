# -----------------------------------------------------------------------------
# multi-agent-shogun Makefile
# -----------------------------------------------------------------------------
# このMakefileは主要なシェルスクリプト (first_setup.sh, shutsujin_departure.sh)
# をラップし、よく使う運用フローを `make <target>` で実行できるようにする。
# START_ARGS 変数を使えば shutsujin_departure.sh に追加オプションを渡せる。
# 例: make start START_ARGS="--shell zsh"
# -----------------------------------------------------------------------------

SHELL := /bin/bash

.DEFAULT_GOAL := help

SHUTSUJIN := ./shutsujin_departure.sh
FIRST_SETUP := ./first_setup.sh
TMUX ?= tmux

QUEUE_DIR := queue
TASK_DIR := $(QUEUE_DIR)/tasks
REPORT_DIR := $(QUEUE_DIR)/reports
LOG_DIR := logs
CONFIG_DIR := config
STATUS_DIR := status
MEMORY_DIR := memory
SKILLS_DIR := skills
DEMO_DIR := demo_output
OUTPUT_DIR := output
TEST_OUTPUT_DIR := test_output

TOOLING_FILE := config/tooling.yaml
PROVIDER := $(strip $(shell if [ -f $(TOOLING_FILE) ]; then awk -F': *' '$$1=="provider"{print $$2; exit}' $(TOOLING_FILE); fi))
ifeq ($(PROVIDER),codex)
	AI_CLI := $(strip $(shell if [ -f $(TOOLING_FILE) ]; then awk -F': *' '$$1=="codex_binary"{print $$2; exit}' $(TOOLING_FILE); fi))
	AI_CLI := $(if $(AI_CLI),$(AI_CLI),codex)
else
	PROVIDER := claude
	AI_CLI := $(strip $(shell if [ -f $(TOOLING_FILE) ]; then awk -F': *' '$$1=="claude_binary"{print $$2; exit}' $(TOOLING_FILE); fi))
	AI_CLI := $(if $(AI_CLI),$(AI_CLI),claude)
endif

START_ARGS ?=

.PHONY: help bootstrap start setup-only terminal kill attach-shogun attach-multiagent \
	status ensure-dirs ensure-perms clean doctor logs

help: ## 利用可能なターゲット一覧を表示
	@printf "\nTargets (set START_ARGS to forward extra flags to shutsujin_departure.sh):\n\n"
	@grep -E '^[a-zA-Z0-9_.-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?##"} {printf "  %-20s %s\n", $$1, $$2}'

bootstrap: ensure-perms ## 初回セットアップ (first_setup.sh) を実行
	$(FIRST_SETUP)

start: ensure-perms ensure-dirs ## フル起動 (将軍 + 家老 + 足軽) を実行
	$(SHUTSUJIN) $(START_ARGS)

setup-only: ensure-perms ensure-dirs ## tmux セッションのみ準備 (Claude 起動なし)
	$(SHUTSUJIN) --setup-only $(START_ARGS)

terminal: ensure-perms ensure-dirs ## Windows Terminal タブ付でフル起動
	$(SHUTSUJIN) --terminal $(START_ARGS)

kill: ## tmux セッション (shogun / multiagent) を安全に終了
	@if command -v $(TMUX) >/dev/null 2>&1; then \
		$(TMUX) kill-session -t shogun 2>/dev/null || true; \
		$(TMUX) kill-session -t multiagent 2>/dev/null || true; \
		echo "✔ tmux sessions cleared"; \
	else \
		echo "tmux command is not available"; \
	fi

attach-shogun: ## 将軍セッションに接続
	$(TMUX) attach-session -t shogun

attach-multiagent: ## 家老 + 足軽セッションに接続
	$(TMUX) attach-session -t multiagent

status: ## 稼働中 tmux セッション一覧を表示
	$(TMUX) ls

ensure-dirs: ## ランタイムディレクトリを作成 (存在する場合は維持)
	@mkdir -p $(TASK_DIR) $(REPORT_DIR) $(LOG_DIR) $(CONFIG_DIR) $(STATUS_DIR) $(MEMORY_DIR) \
		$(SKILLS_DIR) $(DEMO_DIR) $(OUTPUT_DIR) $(TEST_OUTPUT_DIR)

ensure-perms: ## 主要スクリプトに実行権限を付与
	@chmod +x $(FIRST_SETUP) $(SHUTSUJIN) setup.sh 2>/dev/null || true

clean: ## ランタイム成果物 (queue, logs, dashboard 等) を削除
	@rm -rf $(QUEUE_DIR) $(LOG_DIR) $(DEMO_DIR) $(OUTPUT_DIR) $(TEST_OUTPUT_DIR)
	@rm -f dashboard.md queue/shogun_to_karo.yaml queue/karo_to_ashigaru.yaml

logs: ## logs/ ディレクトリ内容を確認
	@if [ -d $(LOG_DIR) ]; then ls -1 $(LOG_DIR); else echo "logs/ がまだ存在しません"; fi

# 依存関係チェック用マクロ
define check_tool
	@if command -v $(1) >/dev/null 2>&1; then \
		printf "✔ %-18s %s\n" "$(1)" "$$ (command -v $(1))"; \
	else \
		printf "✘ %-18s not found\n" "$(1)"; \
		exit 1; \
	fi
endef

doctor: ## tmux / node / npm / 選択したAI CLIが揃っているか確認
	$(call check_tool,tmux)
	$(call check_tool,node)
	$(call check_tool,npm)
	$(call check_tool,$(AI_CLI))
