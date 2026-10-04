import ctypes
import os
import subprocess
import sys
import tkinter as tk
from tkinter import messagebox, ttk

APP_TITLE = "Wi-Fi Guard"


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except AttributeError:
        return False


def relaunch_as_admin():
    params = " ".join(f'"{argument}"' for argument in sys.argv)
    result = ctypes.windll.shell32.ShellExecuteW(
        None,
        "runas",
        sys.executable,
        params,
        os.path.dirname(os.path.abspath(__file__)),
        1,
    )
    if result <= 32:
        raise RuntimeError("Windows could not start the app with administrator rights.")


def run_netsh(arguments):
    completed = subprocess.run(
        ["netsh", "wlan", *arguments],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    output = (completed.stdout + completed.stderr).strip()
    if completed.returncode != 0:
        raise RuntimeError(output or "The Windows WLAN command failed.")
    return output


def block_network(ssid):
    return run_netsh(
        [
            "add",
            "filter",
            "permission=block",
            f"ssid={ssid}",
            "networktype=infrastructure",
        ]
    )


def unblock_network(ssid):
    return run_netsh(
        [
            "delete",
            "filter",
            "permission=block",
            f"ssid={ssid}",
            "networktype=infrastructure",
        ]
    )


class WiFiGuardApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("560x360")
        self.minsize(500, 320)
        self.configure(bg="#f4f1ea")
        self._build_ui()

    def _build_ui(self):
        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure("App.TFrame", background="#f4f1ea")
        style.configure("Title.TLabel", background="#f4f1ea", foreground="#18221f", font=("Segoe UI", 22, "bold"))
        style.configure("Body.TLabel", background="#f4f1ea", foreground="#4b5752", font=("Segoe UI", 10))
        style.configure("Section.TLabel", background="#f4f1ea", foreground="#18221f", font=("Segoe UI", 11, "bold"))
        style.configure("Action.TButton", padding=(14, 8), font=("Segoe UI", 10, "bold"))
        style.configure("Danger.TButton", padding=(14, 8), font=("Segoe UI", 10, "bold"), foreground="#8a2d25")

        root = ttk.Frame(self, padding=28, style="App.TFrame")
        root.pack(fill="both", expand=True)
        ttk.Label(root, text="Wi-Fi Guard", style="Title.TLabel").pack(anchor="w")
        ttk.Label(
            root,
            text="Prevent this Windows PC from joining a selected Wi-Fi network.",
            style="Body.TLabel",
        ).pack(anchor="w", pady=(4, 24))

        ttk.Label(root, text="Network name (SSID)", style="Section.TLabel").pack(anchor="w")
        input_row = ttk.Frame(root, style="App.TFrame")
        input_row.pack(fill="x", pady=(8, 20))
        self.ssid_entry = ttk.Entry(input_row, font=("Segoe UI", 11))
        self.ssid_entry.pack(side="left", fill="x", expand=True, ipady=7)
        self.ssid_entry.bind("<Return>", lambda _event: self.block_selected())
        ttk.Button(input_row, text="Block network", style="Action.TButton", command=self.block_selected).pack(side="left", padx=(10, 0))

        ttk.Label(root, text="Remove a block", style="Section.TLabel").pack(anchor="w")
        remove_row = ttk.Frame(root, style="App.TFrame")
        remove_row.pack(fill="x", pady=(8, 20))
        self.remove_entry = ttk.Entry(remove_row, font=("Segoe UI", 11))
        self.remove_entry.pack(side="left", fill="x", expand=True, ipady=7)
        ttk.Button(remove_row, text="Allow network", style="Danger.TButton", command=self.unblock_selected).pack(side="left", padx=(10, 0))

        self.status = tk.StringVar(value="Ready. Administrator permission is required for changes.")
        status_frame = tk.Frame(root, bg="#e5ebe5", padx=12, pady=12)
        status_frame.pack(fill="x", side="bottom")
        tk.Label(status_frame, textvariable=self.status, bg="#e5ebe5", fg="#30443a", anchor="w", justify="left", wraplength=470, font=("Segoe UI", 9)).pack(fill="x")

    def block_selected(self):
        self._change_network(self.ssid_entry.get(), block_network, "blocked")

    def unblock_selected(self):
        self._change_network(self.remove_entry.get(), unblock_network, "allowed")

    def _change_network(self, ssid, action, result_word):
        ssid = ssid.strip()
        if not ssid:
            messagebox.showwarning(APP_TITLE, "Enter a Wi-Fi network name first.")
            return
        try:
            action(ssid)
        except RuntimeError as error:
            self.status.set(str(error))
            messagebox.showerror(APP_TITLE, str(error))
            return
        self.status.set(f'Network "{ssid}" is now {result_word} on this PC.')
        self.ssid_entry.delete(0, tk.END)
        self.remove_entry.delete(0, tk.END)


def main():
    if os.name != "nt":
        raise SystemExit("Wi-Fi Guard currently supports Windows only.")
    if not is_admin():
        try:
            relaunch_as_admin()
        except RuntimeError as error:
            messagebox.showerror(APP_TITLE, str(error))
        return
    WiFiGuardApp().mainloop()


if __name__ == "__main__":
    main()
