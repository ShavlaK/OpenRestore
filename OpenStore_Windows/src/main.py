import customtkinter as ctk
import subprocess
import threading
import sys
import os

ctk.set_appearance_mode("System")
ctk.set_default_color_theme("blue")

class OpenStoreWin(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("OpenStore (Windows Edition)")
        self.geometry("900x600")

        self.grid_rowconfigure(0, weight=1)
        self.grid_columnconfigure(1, weight=1)

        # Navigation Frame
        self.nav_frame = ctk.CTkFrame(self, corner_radius=0)
        self.nav_frame.grid(row=0, column=0, sticky="nsew")
        self.nav_frame.grid_rowconfigure(4, weight=1)

        self.logo_label = ctk.CTkLabel(self.nav_frame, text="⚡ OpenStore", font=ctk.CTkFont(size=20, weight="bold"))
        self.logo_label.grid(row=0, column=0, padx=20, pady=(20, 10))

        self.btn_device = ctk.CTkButton(self.nav_frame, corner_radius=0, height=40, border_spacing=10, text="📱 Менеджер устройств", fg_color="transparent", text_color=("gray10", "gray90"), hover_color=("gray70", "gray30"), anchor="w", command=self.show_device)
        self.btn_device.grid(row=1, column=0, sticky="ew")

        self.btn_purchases = ctk.CTkButton(self.nav_frame, corner_radius=0, height=40, border_spacing=10, text="☁️ Покупки Apple ID", fg_color="transparent", text_color=("gray10", "gray90"), hover_color=("gray70", "gray30"), anchor="w", command=self.show_purchases)
        self.btn_purchases.grid(row=2, column=0, sticky="ew")

        # Main Content Frame
        self.main_frame = ctk.CTkFrame(self, corner_radius=10)
        self.main_frame.grid(row=0, column=1, sticky="nsew", padx=20, pady=20)
        self.main_frame.grid_rowconfigure(1, weight=1)
        self.main_frame.grid_columnconfigure(0, weight=1)

        self.title_label = ctk.CTkLabel(self.main_frame, text="Устройство", font=ctk.CTkFont(size=24, weight="bold"))
        self.title_label.grid(row=0, column=0, padx=20, pady=20, sticky="nw")

        self.content_area = ctk.CTkTextbox(self.main_frame)
        self.content_area.grid(row=1, column=0, padx=20, pady=(0, 20), sticky="nsew")

        # Progress Frame
        self.progress_frame = ctk.CTkFrame(self.main_frame, height=50)
        self.progress_frame.grid(row=2, column=0, sticky="ew", padx=20, pady=20)
        
        self.progress_label = ctk.CTkLabel(self.progress_frame, text="Ожидание...")
        self.progress_label.pack(side="left", padx=10)
        
        self.progress_bar = ctk.CTkProgressBar(self.progress_frame)
        self.progress_bar.pack(side="left", fill="x", expand=True, padx=10)
        self.progress_bar.set(0)

        self.show_device()

    def get_bin_path(self, bin_name):
        base_path = getattr(sys, '_MEIPASS', os.path.join(os.path.dirname(__file__), '..', 'bin'))
        return os.path.join(base_path, bin_name)

    def show_device(self):
        self.title_label.configure(text="Подключенные устройства (go-ios)")
        self.content_area.delete("1.0", "end")
        self.content_area.insert("end", "Проверка подключенных устройств по USB...\n")
        
        def run_check():
            try:
                ios_path = self.get_bin_path("ios.exe")
                result = subprocess.run([ios_path, "list"], capture_output=True, text=True, creationflags=subprocess.CREATE_NO_WINDOW)
                self.content_area.insert("end", result.stdout + "\n" + result.stderr)
            except Exception as e:
                self.content_area.insert("end", f"Ошибка запуска ios.exe: {e}")
        
        threading.Thread(target=run_check).start()

    def show_purchases(self):
        self.title_label.configure(text="Авторизация Apple ID (ipatool)")
        self.content_area.delete("1.0", "end")
        self.content_area.insert("end", "Нажмите кнопку ниже для тестового запуска ipatool.exe...\n")
        
        btn = ctk.CTkButton(self.main_frame, text="Запустить ipatool --version", command=self.run_ipatool)
        btn.grid(row=3, column=0, pady=10)

    def run_ipatool(self):
        def run():
            try:
                ipatool_path = self.get_bin_path("ipatool.exe")
                result = subprocess.run([ipatool_path, "--version"], capture_output=True, text=True, creationflags=subprocess.CREATE_NO_WINDOW)
                self.content_area.insert("end", result.stdout + "\n" + result.stderr)
            except Exception as e:
                self.content_area.insert("end", f"Ошибка запуска ipatool.exe: {e}")
                
        threading.Thread(target=run).start()

if __name__ == "__main__":
    app = OpenStoreWin()
    app.mainloop()
