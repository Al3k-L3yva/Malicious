import pyautogui
import tkinter as tk 
from tkinter import messagebox 
import threading
import random
import time
import math
import ctypes

# CONFIGURACION DE SEGURIDAD

#mover mouse a esquina superior izquierda para detener
pyautogui.FAILSAFE = True

class Simulador:
    def __init__(self):
        self.running = True
        self.windows = []
        self.screen_width, self.screen_height = pyautogui.size()
        
    def moverMouse(self):
        # MUEVE EL MOUSE ALEATORIAMENTE
        while self.running:
            x = random.randint(0, self.screen_width)
            y = random.randint(0, self.screen_height)
            pyautogui.moveTo(x, y, duration = random.uniform(0.1, 0.5))
            time.sleep(random.uniform(0.5, 2))
            
    def sacudirMouse(self):
        start_x, start_y = pyautogui.position()
        while self.running:
            for offset in range(10):
                if not self.running:
                    break
                pyautogui.moveTo(start_x + random.randint(-10, 10), start_y+ random.randint(-10, 10), duration = 0.01)
                time.sleep(0.02)
                
            # REGRESAR MOUSE A LA POSICION ORIGINAL
            pyautogui.moveTo(start_x, start_y, duration = 0.1)
            time.sleep(random.uniform(2, 5))
            
    def tamanioMouse(self):
        while self.running:
            for size in [32, 48, 64, 32]:
                if not self.running:
                    break
                try:
                    ctypes.windll.user32.SystemParametersInfoW(0x102B, 0, size, 0)
                except:
                    pass
                time.sleep(0.5)
            time.sleep(random.uniform(3,5))
            
    def create_popup_window(self, title, message, x, y):
        """Crea ventanas emergentes"""
        if not self.running:
            return
        
        popup = tk.Toplevel()
        popup.title(title)
        popup.geometry(f"300x150+{x}+{y}")
        popup.configure(bg='black')
        
        label = tk.Label(popup, text=message, fg='red', bg='black', 
                        font=('Arial', 10, 'bold'))
        label.pack(pady=20)
        
        btn = tk.Button(popup, text="Cerrar", command=popup.destroy)
        btn.pack()
        
        self.windows.append(popup)
        
        # Auto-cierre después de 3 segundos
        popup.after(3000, lambda: self.close_window(popup))
    
    def close_window(self, window):
        """Cierra una ventana específica"""
        if window in self.windows:
            self.windows.remove(window)
            try:
                window.destroy()
            except:
                pass
    
    
    
    
    
    def flash_pantalla(self):
        """Parpadeo de pantalla usando ventanas de colores"""
        while self.running:
            # Ventana de parpadeo
            flash = tk.Toplevel()
            flash.attributes('-fullscreen', True)
            flash.attributes('-topmost', True)
            flash.configure(bg=random.choice(['red', 'blue', 'green', 'yellow', 'white']))
            flash.attributes('-alpha', 0.3)  # Semi-transparente
            
            time.sleep(0.1)
            flash.destroy()
            time.sleep(random.uniform(0.5, 1.5))

    def abrir_cerrar_ventanas(self):
        """Abre y cierra ventanas continuamente"""
        messages = [
            "⚠️ ALERTA ⚠️", "🔥 VIRUS DETECTADO 🔥", "💀 ERROR CRÍTICO 💀",
            "🎭 EFECTO VISUAL 🎭", "⚡ SIMULACIÓN ⚡", "👻 BOO! 👻"
        ]
        
        while self.running:
            # Crear múltiples ventanas
            for _ in range(random.randint(2, 5)):
                if not self.running:
                    break
                x = random.randint(0, self.screen_width - 300)
                y = random.randint(0, self.screen_height - 150)
                msg = random.choice(messages)
                title = f"Alerta {random.randint(1, 999)}"
                self.create_popup_window(title, msg, x, y)
                time.sleep(0.3)
            
            # Esperar y cerrar algunas ventanas
            time.sleep(random.uniform(2, 4))
            if len(self.windows) > 10:  # Limitar número de ventanas
                for _ in range(random.randint(3, 5)):
                    if self.windows:
                        self.close_window(random.choice(self.windows))
                
     def run(self):
        """Ejecuta todos los efectos en paralelo"""
        print("="*50)
        print("🎭 SIMULADOR DE EFECTOS VIRALES 🎭")
        print("="*50)
        print("⚠️ Esto es solo un efecto VISUAL - NO es un virus real")
        print("✅ No daña archivos ni el sistema")
        print("🛑 Mueve el mouse a la esquina superior izquierda para detener")
        print("🛑 O presiona Ctrl+C en esta terminal")
        print("="*50)
        print("Iniciando efectos en 3 segundos...")
        time.sleep(3)
        
        # Crear hilos para efectos simultáneos
        threads = [
            threading.Thread(target=self.moverMouse),
            threading.Thread(target=self.sacudirMouse),
            threading.Thread(target=self.abrir_cerrar_ventanas),
            # threading.Thread(target=self.resize_windows),
            # threading.Thread(target=self.flash_screen),  # Descomentar con precaución
            threading.Thread(target=self.tamanioMouse),  # Descomentar en Windows
        ]
        
        for thread in threads:
            thread.daemon = True
            thread.start()
        
        # Mantener el programa corriendo
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop()
    
    def stop(self):
        """Detiene todos los efectos"""
        self.running = False
        # Cerrar todas las ventanas
        for window in self.windows[:]:
            self.close_window(window)
        
        # Restaurar cursor (si se modificó)
        try:
            ctypes.windll.user32.SystemParametersInfoW(0x102B, 0, 32, 0)
        except:
            pass
        
        print("\n✅ Simulación detenida. Todo ha sido restaurado.")
        messagebox.showinfo("Simulación finalizada", 
                           "Los efectos visuales han cesado.\n"
                           "Todo está normal nuevamente.")

# Ejecutar
if __name__ == "__main__":
    # Verificar dependencias
    try:
        import pyautogui
        import tkinter
    except ImportError as e:
        print(f"❌ Falta instalar: {e}")
        print("Ejecuta: pip install pyautogui")
        exit(1)
    
    simulator = Simulador()
    simulator.run()