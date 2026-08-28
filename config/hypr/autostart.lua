-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Keep the keyboard layout (e.g. Norwegian) across the lock screen. Omarchy's
-- lock script always resets to the first layout (English) on lock; this
-- restores whatever layout was active right before locking.
o.launch_on_start(os.getenv("HOME") .. "/.local/bin/omarchy-restore-lock-keyboard-layout")
