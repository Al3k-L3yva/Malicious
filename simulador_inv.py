"""
SIMULADOR INVISIBLE - No muestra ventanas, solo efectos
Ejecutar con pythonw.exe para que no se vea la consola
"""

import pyautogui
import tkinter as tk
import threading
import random
import time
import ctypes
import subprocess
import webbrowser
import sys
import os

# Ocultar consola de Python (si se ejecuta con python.exe)
if sys.platform == "win32":
    ctypes.windll.user32.ShowWindow(ctypes.windll.kernel32.GetConsoleWindow(), 0)

pyautogui.FAILSAFE = True

class SilentSimulator:
    def __init__(self):
        self.running = True
        self.screen_width, self.screen_height = pyautogui.size()
        self.notepad_processes = []
        
    def move_mouse_randomly(self):
        while self.running:
            x = random.randint(0, self.screen_width)
            y = random.randint(0, self.screen_height)
            pyautogui.moveTo(x, y, duration=random.uniform(0.1, 0.5))
            time.sleep(random.uniform(0.5, 2))
    
    def shake_mouse(self):
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
    
    def open_notepad(self):
        mensajes = [
            "¿Quién está escribiendo esto?",
            "TU YA NO CONTROLAS ESTO",
            " está controlando el teclado",
            "sudo make me a sandwich",
            "ShellShockers is now on your system",
            "¿SEGURO QUE PODRAS TERMINAR?",
            "¡Sorpresa! DaemonHunters esta contigo",
            "CADA VEZ GANAMOS MAS CONTROL SOBRE TU MAQUINA",
            "Tal vez llamar a TacoOverflow para pedir ayuda sirva :("
        ]
        
        while self.running:
            try:
                notepad = subprocess.Popen("notepad.exe", shell=True, 
                                          creationflags=subprocess.CREATE_NO_WINDOW)
                self.notepad_processes.append(notepad)
                time.sleep(1)
                
                mensaje = random.choice(mensajes)
                pyautogui.write(mensaje, interval=0.05)
                pyautogui.press('enter')
                time.sleep(0.5)
                pyautogui.write(f"Hora: {time.strftime('%H:%M:%S')}", interval=0.05)
                
                time.sleep(random.uniform(3, 5))
                
                # Cerrar bloc de notas después de escribir
                if notepad in self.notepad_processes:
                    notepad.terminate()
                    self.notepad_processes.remove(notepad)
                    
            except:
                pass
            time.sleep(random.uniform(10, 20))
    
    def open_random_pages(self):
        urls = [
            "https://www.google.com",
            "https://www.wikipedia.org",
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        ]
        
        while self.running:
            try:
                url = random.choice(urls)
                webbrowser.open(url)
                time.sleep(random.uniform(3, 5))
                pyautogui.hotkey('ctrl', 'w')  # Cerrar pestaña
            except:
                pass
            time.sleep(random.uniform(15, 30))
    
    def type_random_messages(self):
        frases = [
            "¿Quién está escribiendo esto?",
            "TU YA NO CONTROLAS ESTO",
            " está controlando el teclado",
            "sudo make me a sandwich",
            "ShellShockers is now on your system",
            "¿SEGURO QUE PODRAS TERMINAR?",
            "¡Sorpresa! DaemonHunters esta contigo",
            "CADA VEZ GANAMOS MAS CONTROL SOBRE TU MAQUINA",
            "Tal vez llamar a TacoOverflow para pedir ayuda sirva :("
        ]
        
        while self.running:
            time.sleep(random.uniform(20, 40))
            try:
                frase = random.choice(frases)
                pyautogui.write(frase, interval=0.08)
                pyautogui.press('enter')
            except:
                pass
    
    def run(self):
        threads = [
            threading.Thread(target=self.move_mouse_randomly, daemon=True),
            threading.Thread(target=self.shake_mouse, daemon=True),
            threading.Thread(target=self.open_notepad, daemon=True),
            threading.Thread(target=self.open_random_pages, daemon=True),
            threading.Thread(target=self.type_random_messages, daemon=True),
        ]
        
        for thread in threads:
            thread.start()
        
        try:
            while self.running:
                time.sleep(1)
        except:
            pass
    
    def stop(self):
        self.running = False
        for proc in self.notepad_processes:
            try:
                proc.terminate()
            except:
                pass

if __name__ == "__main__":
    simulator = SilentSimulator()
    simulator.run()