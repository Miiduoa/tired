.PHONY: help webhook-test webhook-serve webhook-send webhook-stop webhook-logs

PORT ?= 34567
SECRET ?= demo_secret
EVENT ?= message.ack
TMP := .tmp
URL := http://localhost:$(PORT)/webhooks/tired

help:
	@echo "Targets:"
	@echo "  make webhook-test            # start server, send $(EVENT), show logs, stop"
	@echo "  make webhook-serve           # start local webhook server (PORT, SECRET)"
	@echo "  make webhook-send EVENT=...  # send signed webhook (uses scripts/send_webhook.py)"
	@echo "  make webhook-logs            # print server log"
	@echo "  make webhook-stop            # stop server"
	@echo "  make ios-run                 # build + run iOS app (auto device detect)"
	@echo "  make ios-uitest              # run UI tests (auto device detect)"
	@echo "Vars: PORT=$(PORT), SECRET=$(SECRET), EVENT=$(EVENT)"

$(TMP):
	mkdir -p $(TMP)

webhook-serve: $(TMP)
	@TIRED_WEBHOOK_SECRET=$(SECRET) PORT=$(PORT) python3 scripts/webhook_test_server_py.py > $(TMP)/webhook.log 2>&1 & echo $$! > $(TMP)/webhook.pid; \
		echo "[listening] $(URL) (SECRET=$(SECRET))"

webhook-send:
	@case "$(EVENT)" in \
		message.ack) FILE="docs/api/examples/message.ack.json" ;; \
		attendance.closed) FILE="docs/api/examples/attendance.closed.json" ;; \
		clock.recorded) FILE="docs/api/examples/clock.recorded.json" ;; \
		esg.report.ready) FILE="docs/api/examples/esg.report.ready.json" ;; \
		policy.violation) FILE="docs/api/examples/policy.violation.json" ;; \
		unmask.approved) FILE="docs/api/examples/unmask.approved.json" ;; \
		*) echo "[error] unknown EVENT=$(EVENT)"; exit 2 ;; \
	 esac; \
	 python3 scripts/send_webhook.py --url "$(URL)" --secret "$(SECRET)" --event "$(EVENT)" --file "$$FILE"

webhook-logs:
	@sed -n '1,200p' $(TMP)/webhook.log || true

webhook-stop:
	@kill "$$(cat $(TMP)/webhook.pid)" >/dev/null 2>&1 || true; rm -f $(TMP)/webhook.pid; echo "[stopped]"

webhook-test: webhook-serve
	@sleep 0.8; $(MAKE) -s webhook-send; echo '--- server log ---'; $(MAKE) -s webhook-logs; $(MAKE) -s webhook-stop

# iOS helpers
ios-run:
	@DEVICE="$(or $(DEVICE),)" TIRED_API_URL="$(TIRED_API_URL)" bash tired/tired/scripts/ios_build_run.sh

ios-uitest:
	@bash tired/tired/scripts/ios_ui_test.sh
