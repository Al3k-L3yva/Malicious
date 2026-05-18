import pyautogui
import tkinter as tk
from tkinter import messagebox
import threading
import random
import time
import math
import ctypes
import subprocess
import webbrowser

# Configuración de seguridad
pyautogui.FAILSAFE = True  # Mover mouse a esquina superior izquierda para detener

class ViralSimulator:
    def __init__(self):
        self.running = True
        self.windows = []
        self.screen_width, self.screen_height = pyautogui.size()
        self.notepad_processes = []  # Para rastrear bloc de notas abiertos
        
    def move_mouse_randomly(self):
        """Mueve el mouse aleatoriamente"""
        while self.running:
            x = random.randint(0, self.screen_width)
            y = random.randint(0, self.screen_height)
            pyautogui.moveTo(x, y, duration=random.uniform(0.1, 0.5))
            time.sleep(random.uniform(0.5, 2))
    
    def shake_mouse(self):
        """Hace vibrar el mouse"""
        while self.running:
            start_x, start_y = pyautogui.position()
            for _ in range(10):
                if not self.running:
                    break
                pyautogui.moveTo(start_x + random.randint(-10, 10), 
                               start_y + random.randint(-10, 10),
                               duration=0.01)
                time.sleep(0.02)
            pyautogui.moveTo(start_x, start_y, duration=0.1)
            time.sleep(random.uniform(2, 5))
    
    def change_cursor_size(self):
        """Cambia el tamaño del puntero (Windows)"""
        while self.running:
            for size in [32, 48, 64, 32]:
                if not self.running:
                    break
                try:
                    ctypes.windll.user32.SystemParametersInfoW(0x102B, 0, size, 0)
                except:
                    pass
                time.sleep(0.5)
            time.sleep(random.uniform(3, 5))
    
    def open_notepad(self):
        """Abre el Bloc de notas y escribe mensajes"""
        websites = [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",  # Rick Roll
            "https://es.wikipedia.org/wiki/Wikipedia:Portada",
            "https://www.google.com",
            "https://github.com",
            "https://stackoverflow.com"
        ]
        
        mensajes = [
            "Hola, esto es una simulación",
            "No te preocupes, es solo un efecto visual",
            "Este bloc de notas se abrió automáticamente",
            "Python es divertido!",
            "Ctrl+C para detener el programa",
            "😊 Esto es inofensivo",
            "¡Sorpresa! Es solo una broma visual"
        ]
        
        while self.running:
            try:
                # Abrir Bloc de notas
                notepad = subprocess.Popen("notepad.exe")
                self.notepad_processes.append(notepad)
                time.sleep(1)
                
                # Escribir mensaje aleatorio
                mensaje = random.choice(mensajes)
                pyautogui.write(mensaje, interval=0.05)
                time.sleep(0.5)
                
                # Agregar línea en blanco y más texto
                pyautogui.press('enter')
                time.sleep(0.3)
                pyautogui.write(f"Escrito automáticamente a las {time.strftime('%H:%M:%S')}", interval=0.05)
                pyautogui.press('enter')
                time.sleep(0.3)
                
                # Opcional: escribir números aleatorios
                for _ in range(random.randint(1, 3)):
                    pyautogui.write(str(random.randint(1, 1000)), interval=0.05)
                    pyautogui.press('enter')
                    time.sleep(0.2)
                
                # Esperar antes de abrir otro
                time.sleep(random.uniform(5, 10))
                
                # Cerrar algunos bloc de notas si hay muchos
                if len(self.notepad_processes) > 3:
                    for proc in self.notepad_processes[:2]:
                        try:
                            proc.terminate()
                            self.notepad_processes.remove(proc)
                        except:
                            pass
                            
            except Exception as e:
                print(f"Error en open_notepad: {e}")
                time.sleep(2)
    
    def open_edge_random_pages(self):
        """Abre Microsoft Edge con páginas aleatorias"""
        # Lista de URLs divertidas/inofensivas
        urls = [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",  # Rick Roll
            "https://es.wikipedia.org/wiki/Wikipedia:Portada",
            "https://www.google.com",
            "https://github.com",
            "https://stackoverflow.com",
            "https://www.duckduckgo.com",
            "https://www.bing.com",
            "https://www.reddit.com/r/ProgrammerHumor/",
            "https://pointerpointer.com",  # Sitio divertido
            "https://hackertyper.net",      # Simula hacking
            # "https://patorjk.com/software/taag/",  # Generador ASCII art
            "https://theuselessweb.com",    # Sitios inútiles
        ]
        
        # Mensajes de búsqueda para simular escritura
        busquedas = [
            "¿Qué es Python?",
            "Tutorial de programación",
            "Efectos visuales divertidos",
            "Gatos graciosos",
            "Música relajante",
            "Noticias de tecnología",
            "Recetas de cocina fáciles"
        ]
        
        while self.running:
            try:
                # Elegir URL aleatoria
                url = random.choice(urls)
                
                # Abrir Edge (o navegador por defecto)
                # Método 1: Usar webbrowser (usa navegador predeterminado)
                webbrowser.open(url)
                
                # Método 2: Forzar Edge (descomentar si quieres Edge específicamente)
                # subprocess.Popen(["msedge.exe", url])
                
                time.sleep(2)  # Esperar a que cargue
                
                # Opcional: Simular búsqueda en Google (si abrió Google)
                if "google" in url.lower():
                    time.sleep(2)
                    # Hacer clic en la barra de búsqueda
                    pyautogui.click(300, 150)  # Coordenadas aproximadas
                    time.sleep(0.5)
                    # Escribir búsqueda aleatoria
                    busqueda = random.choice(busquedas)
                    pyautogui.write(busqueda, interval=0.1)
                    time.sleep(0.5)
                    pyautogui.press('enter')
                
                # Esperar antes de abrir otra página
                tiempo_espera = random.uniform(5, 15)
                print(f"Esperando {tiempo_espera:.1f} segundos antes de abrir otra página...")
                time.sleep(tiempo_espera)
                
                # Cerrar algunas pestañas si hay muchas (presionar Ctrl+W)
                if random.random() < 0.3:  # 30% de probabilidad
                    pyautogui.hotkey('ctrl', 'w')
                    print("Cerrando pestaña actual...")
                    
            except Exception as e:
                print(f"Error en open_edge_random_pages: {e}")
                time.sleep(2)
    
    def type_random_messages(self):
        """Escribe mensajes aleatorios en la ventana activa"""
        frases = [
            "¿Quién está escribiendo esto?",
            "Efecto visual divertido!",
            "Python está controlando el teclado",
            "Esto es solo una simulación",
            "No te preocupes, no es un virus real",
            "Presiona Ctrl+C en la terminal para detener",
            "¡Sorpresa! 🎉",
            "Este texto se escribe automáticamente"
        ]
        
        while self.running:
            try:
                time.sleep(random.uniform(10, 25))  # Esperar un rato
                
                # Escribir frase aleatoria
                frase = random.choice(frases)
                print(f"Escribiendo: {frase}")
                pyautogui.write(frase, interval=0.08)
                pyautogui.press('enter')
                
            except Exception as e:
                print(f"Error en type_random_messages: {e}")
                time.sleep(2)
    
    def create_popup_window(self, title, message, x, y):
        """Crea ventanas emergentes"""
        if not self.running:
            return
        
        try:
            popup = tk.Toplevel()
            popup.title(title)
            
            # Asegurar coordenadas válidas
            x = max(0, min(x, self.screen_width - 300))
            y = max(0, min(y, self.screen_height - 150))
            
            popup.geometry(f"300x150+{x}+{y}")
            popup.configure(bg='black')
            
            label = tk.Label(popup, text=message, fg='red', bg='black', 
                            font=('Arial', 10, 'bold'))
            label.pack(pady=20)
            
            btn = tk.Button(popup, text="Cerrar", command=popup.destroy)
            btn.pack()
            
            self.windows.append(popup)
            popup.after(3000, lambda: self.close_window(popup))
            
        except Exception as e:
            print(f"Error creando ventana: {e}")
    
    def close_window(self, window):
        """Cierra una ventana específica"""
        if window in self.windows:
            self.windows.remove(window)
            try:
                window.destroy()
            except:
                pass
    
    def open_close_windows(self):
        """Abre y cierra ventanas continuamente"""
        messages = [
            "⚠️ ALERTA ⚠️", "🔥 VIRUS DETECTADO 🔥", "💀 ERROR CRÍTICO 💀",
            "🎭 EFECTO VISUAL 🎭", "⚡ SIMULACIÓN ⚡", "👻 BOO! 👻",
            "🤖 SIMULADOR ACTIVO", "💻 PYTHON RULES", "🐍 SERPENTE"
        ]
        
        while self.running:
            try:
                # Crear múltiples ventanas
                for _ in range(random.randint(2, 4)):
                    if not self.running:
                        break
                    
                    # Calcular coordenadas seguras
                    max_x = max(100, self.screen_width - 350)
                    max_y = max(100, self.screen_height - 200)
                    
                    x = random.randint(50, max_x) if max_x > 50 else 50
                    y = random.randint(50, max_y) if max_y > 50 else 50
                    
                    msg = random.choice(messages)
                    title = f"Alerta {random.randint(1, 999)}"
                    self.create_popup_window(title, msg, x, y)
                    time.sleep(0.3)
                
                time.sleep(random.uniform(2, 4))
                
                if len(self.windows) > 10:
                    for _ in range(random.randint(3, 5)):
                        if self.windows:
                            self.close_window(random.choice(self.windows))
                            
            except Exception as e:
                print(f"Error en open_close_windows: {e}")
                time.sleep(1)
    
    def resize_windows(self):
        """Cambia tamaño de ventanas existentes"""
        while self.running:
            if self.windows:
                window = random.choice(self.windows)
                try:
                    new_width = random.randint(100, 500)
                    new_height = random.randint(100, 400)
                    new_x = random.randint(0, max(0, self.screen_width - new_width))
                    new_y = random.randint(0, max(0, self.screen_height - new_height))
                    window.geometry(f"{new_width}x{new_height}+{new_x}+{new_y}")
                except:
                    pass
            time.sleep(random.uniform(0.5, 1.5))
    
    def flash_screen(self):
        """Parpadeo de pantalla usando ventanas de colores"""
        while self.running:
            try:
                flash = tk.Toplevel()
                flash.attributes('-fullscreen', True)
                flash.attributes('-topmost', True)
                flash.configure(bg=random.choice(['red', 'blue', 'green', 'yellow', 'white']))
                flash.attributes('-alpha', 0.3)
                
                time.sleep(0.1)
                flash.destroy()
                time.sleep(random.uniform(0.5, 1.5))
            except:
                pass
    
    def run(self):
        """Ejecuta todos los efectos en paralelo"""
        print("="*55)
        print("     🎭 SIMULADOR DE EFECTOS VIRALES 🎭")
        print("="*55)
        print("⚠️ Esto es solo un efecto VISUAL - NO es un virus real")
        print("✅ No daña archivos ni el sistema")
        print("🖱️ El programa controlará el mouse y teclado")
        print("📝 Abrirá Bloc de notas y escribirá mensajes")
        print("🌐 Abrirá páginas web aleatorias")
        print("🛑 Mueve el mouse a la esquina superior izquierda para detener")
        print("🛑 O presiona Ctrl+C en esta terminal")
        print("="*55)
        print("Iniciando efectos en 5 segundos...")
        print("(Prepara tu mouse para detenerlo si es necesario)")
        time.sleep(5)
        
        # Crear hilos para efectos simultáneos
        threads = [
            threading.Thread(target=self.move_mouse_randomly, daemon=True),
            threading.Thread(target=self.shake_mouse, daemon=True),
            threading.Thread(target=self.open_close_windows, daemon=True),
            threading.Thread(target=self.resize_windows, daemon=True),
            threading.Thread(target=self.open_notepad, daemon=True),
            threading.Thread(target=self.open_edge_random_pages, daemon=True),
            threading.Thread(target=self.type_random_messages, daemon=True),
            # threading.Thread(target=self.flash_screen, daemon=True),
            # threading.Thread(target=self.change_cursor_size, daemon=True),
        ]
        
        for thread in threads:
            thread.start()
        
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop()
    
    def stop(self):
        """Detiene todos los efectos"""
        print("\n🛑 Deteniendo simulación...")
        self.running = False
        
        # Cerrar bloc de notas abiertos
        for proc in self.notepad_processes:
            try:
                proc.terminate()
            except:
                pass
        
        # Cerrar todas las ventanas
        for window in self.windows[:]:
            self.close_window(window)
        
        # Restaurar cursor
        try:
            ctypes.windll.user32.SystemParametersInfoW(0x102B, 0, 32, 0)
        except:
            pass
        
        print("\n✅ Simulación detenida. Todo ha sido restaurado.")
        
        try:
            messagebox.showinfo("Simulación finalizada", 
                               "Los efectos visuales han cesado.\n"
                               "Todo está normal nuevamente.\n\n"
                               "Nota: Las páginas web abiertas permanecen abiertas.")
        except:
            pass

# Ejecutar
if __name__ == "__main__":
    print("="*55)
    print("   🐍 SIMULADOR DE EFECTOS VISUALES CON PYTHON")
    print("="*55)
    print()
    
    try:
        import pyautogui
        import tkinter
    except ImportError as e:
        print(f"❌ Error: {e}")
        print("Ejecuta: pip install pyautogui")
        exit(1)
    
    print("ADVERTENCIA: Este programa controlará tu mouse y teclado")
    print("y abrirá ventanas y navegadores automáticamente.\n")
    
    confirm = input("¿Estás seguro de que quieres continuar? (sí/no): ").strip().lower()
    
    if confirm in ["si", "sí", "s", "yes", "y"]:
        simulator = ViralSimulator()
        simulator.run()
    else:
        print("Simulación cancelada.")