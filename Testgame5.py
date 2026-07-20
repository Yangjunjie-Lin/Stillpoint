import tkinter as tk          
from tkinter import messagebox  
from PIL import Image, ImageTk   # type: ignore
import random                   
import math                     
import time                     

class MainMenu:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Game Menu")
        
        # Set window size to fullscreen
        self.root.attributes('-fullscreen', True)
        self.screen_width = self.root.winfo_screenwidth()
        self.screen_height = self.root.winfo_screenheight()
        
        # Create main frame
        main_frame = tk.Frame(self.root)
        main_frame.pack(expand=True)
        
        # Game title
        title_label = tk.Label(
            main_frame, 
            text="Survive", 
            font=('Arial', 48, 'bold'),
            pady=40
        )
        title_label.pack()
        
        # Button style configuration
        button_width = 25
        button_height = 2
        button_font = ('Arial', 14)
        button_pady = 15

        # Start Game button
        self.start_button = tk.Button(
            main_frame,
            text="Start Game",
            width=button_width,
            height=button_height,
            font=button_font,
            command=self.start_game
        )
        self.start_button.pack(pady=button_pady)
        
        # Game Rules button
        self.rules_button = tk.Button(
            main_frame,
            text="Game Rules",
            width=button_width,
            height=button_height,
            font=button_font,
            command=self.show_rules
        )
        self.rules_button.pack(pady=button_pady)
        
        # Leaderboard button
        self.leaderboard_button = tk.Button(
            main_frame,
            text="Leaderboard",
            width=button_width,
            height=button_height,
            font=button_font,
            command=self.show_leaderboard
        )
        self.leaderboard_button.pack(pady=button_pady)
        
        # Exit button
        self.exit_button = tk.Button(
            main_frame,
            text="Exit",
            width=button_width,
            height=button_height,
            font=button_font,
            command=self.root.quit
        )
        self.exit_button.pack(pady=button_pady)
        
        # Add F11 binding for fullscreen toggle
        self.root.bind('<F11>', self.toggle_fullscreen)
        self.root.bind('<Escape>', self.toggle_fullscreen)
        
        # Create game instance but don't start it yet
        self.game = None

    def toggle_fullscreen(self, event=None):
        """Toggle fullscreen mode"""
        is_fullscreen = self.root.attributes('-fullscreen')
        self.root.attributes('-fullscreen', not is_fullscreen)

    def start_game(self):
        """Start a new game"""
        self.root.withdraw()  # Hide menu window
        game_window = tk.Toplevel(self.root)  # Create new window for game
        self.game = ExplorationandShottingGame(menu=self, root=game_window)
        self.game.run()

    def show_rules(self):
        """Show game rules window"""
        rules_window = tk.Toplevel(self.root)
        rules_window.title("Game Rules")
        rules_window.geometry("500x750")
        
        instructions = """
        Game Instructions:

        1. Controls:
        - Use WASD keys to move
        - Left click to shoot
        - Press ESC to pause game
        - Press 'b' to toggle boss mode
        - Press F11 to toggle fullscreen

        2. Items:
        - Green: Shield (10s invincibility)
        - Cyan: Speed boost (5s)
        - Pink: Double score (8s)
        - Orange: Double shot (8s)
        - Red: Pierce shot (8s)
        - Purple: Large shot (8s)

        3. Obstacles:
        - Red: Chase type
        - Yellow: Avoid type
        - Orange: Circle type

        4. Scoring:
        - Collect items: 10 points
        - Shoot obstacles: 20 points
        - Survival time: 1 point per second

        5. Special Features:
        - Boss Key (b): Quick switch to spreadsheet view
        - Show Parameters (F10)
        - Fullscreen Toggle (F11)
        - Pause Menu (ESC)
            * Continue Game
            * Restart Game
            * Exit to Menu
        
        Good luck and have fun!
        """
        
        tk.Label(
            rules_window, 
            text=instructions, 
            justify=tk.LEFT,
            font=('Arial', 12),
            padx=20, 
            pady=20
        ).pack()

    def show_leaderboard(self):
        """Show leaderboard window"""
        leaderboard_window = tk.Toplevel(self.root)
        leaderboard_window.title("Leaderboard")
        leaderboard_window.geometry("400x600")
        
        # Create title label
        title_label = tk.Label(
            leaderboard_window, 
            text="Game Leaderboard", 
            font=('Arial', 24, 'bold')
        )
        title_label.pack(pady=20)
        
        # Create content frame
        content_frame = tk.Frame(leaderboard_window)
        content_frame.pack(fill=tk.BOTH, expand=True, padx=30)
        
        # Add headers with larger font
        header_rank = tk.Label(content_frame, text="Rank", font=('Arial', 16, 'bold'))
        header_name = tk.Label(content_frame, text="Player", font=('Arial', 16, 'bold'))
        header_score = tk.Label(content_frame, text="Score", font=('Arial', 16, 'bold'))
        
        header_rank.grid(row=0, column=0, padx=20, pady=10)
        header_name.grid(row=0, column=1, padx=20, pady=10)
        header_score.grid(row=0, column=2, padx=20, pady=10)
        
        try:
            leaderboard = []
            try:
                with open('leaderboard.txt', 'r', encoding='utf-8') as f:
                    for line in f:
                        if line.strip():
                            name, score_str = line.strip().split(',')
                            leaderboard.append((name, int(score_str)))
            except FileNotFoundError:
                pass

            for i, (name, score) in enumerate(leaderboard, 1):
                rank_label = tk.Label(content_frame, text=f"No.{i}", font=('Arial', 14))
                name_label = tk.Label(content_frame, text=name, font=('Arial', 14))
                score_label = tk.Label(content_frame, text=str(score), font=('Arial', 14))
                
                rank_label.grid(row=i, column=0, padx=20, pady=5)
                name_label.grid(row=i, column=1, padx=20, pady=5)
                score_label.grid(row=i, column=2, padx=20, pady=5)
        
        except Exception as e:
            tk.Label(
                content_frame,
                text="Error loading leaderboard",
                fg="red",
                font=('Arial', 14)
            ).grid(row=1, column=0, columnspan=3)
        
        # Close button
        tk.Button(
            leaderboard_window,
            text="Close",
            command=leaderboard_window.destroy,
            font=('Arial', 12),
            width=15,
            height=2
        ).pack(pady=20)

    def return_to_menu(self):
        """Show the menu window again"""
        self.root.deiconify()

    def run(self):
        """Start the menu"""
        self.root.mainloop()

class ExplorationandShottingGame:
    def __init__(self, menu=None, root=None):
        # Store reference to menu
        self.menu = menu
        
        # Create the main window
        self.root = root if root else tk.Tk()
        self.root.title("Survive")
        
        # Set fullscreen and get screen dimensions
        self.root.attributes('-fullscreen', True)
        self.screen_width = self.root.winfo_screenwidth()
        self.screen_height = self.root.winfo_screenheight()
        
        # Add states
        self.is_paused = False
        self.is_boss_mode = False
        self.pause_menu = None
        
        # Player's name
        self.player_name = None
        self.get_player_name()
        
        # The canvas parameters
        self.canvas_width = self.screen_width
        self.canvas_height = self.screen_height
        self.player_size = 25  # Slightly larger for bigger screen
        self.visible_radius = 200  # Larger visible area
        self.obstacle_size = 25
        self.item_size = 20
        self.map_size = max(2400, self.screen_width * 2)  # Ensure map is at least 2x screen size
        
        # Load background image
        try:
            self.background_image = Image.open("background.png")
            # Resize for better performance
            visible_area_width = self.canvas_width * 2
            visible_area_height = self.canvas_height * 2
            self.background_image = self.background_image.resize(
                (visible_area_width, visible_area_height)
            )
            self.background_photo = ImageTk.PhotoImage(self.background_image)
        except Exception as e:
            print(f"Error loading background: {e}")
            self.background_photo = None

        # Dynamic Difficulty Adjustment
        self.difficulty_scale = 1.0
        self.base_obstacle_count = 10
        self.max_obstacle_count = 60
        self.score_threshold = 200
        
        # Create canvas
        self.canvas = tk.Canvas(
            self.root,
            width=self.canvas_width,
            height=self.canvas_height,
            bg='black')
        self.canvas.pack()
        
        # Game state initialization remains same but centered on screen
        self.player_x = self.canvas_width // 2
        self.player_y = self.canvas_height // 2
        self.player_world_x = self.player_x
        self.player_world_y = self.player_y
        self.map_offset_x = 0
        self.map_offset_y = 0
        
        # Player's parameters
        self.base_speed = 7  # Slightly faster for larger screen
        self.current_speed = self.base_speed
        self.shield_active = False
        self.shield_end_time = 0
        self.speed_boost_end_time = 0
        self.score_multiplier = 1
        self.score_multiplier_end_time = 0
        
        # Shooting system
        self.bullets = []
        self.bullet_speed = 15
        self.bullet_size = 6
        self.bullet_damage = 1
        self.shooting_cooldown = 0.5
        self.last_shot_time = 0

        # Weapon system
        self.weapon_type = "normal" 
        self.weapon_end_time = 0
        self.double_shot_offset = 10
        
        # Survival score system
        self.start_time = time.time()
        self.survival_score = 0
        self.survival_score_rate = 1
        
        # Items and killing score system
        self.items = []
        self.score = 0
        self.item_spawn_timer = 0
        self.item_spawn_interval = 100
        
        # Initialize obstacles and items
        self.obstacles = []
        self.generate_obstacles()
        self.generate_initial_items()
        
        self.cheat_input = ""
        self.cheat_codes = {
            "godmode": "immortal",
            "rapidfire": "flash",
            "powerup": "allitems",
            "points": "rich",
            "speedup": "sonic",
        }
        self.god_mode = False
        self.rapid_fire = False

        # Add these variables
        self.velocity_x = 0
        self.velocity_y = 0
        self.acceleration = 0.5
        self.friction = 0.85
        self.pressed_keys = set()
        self.show_parameters = False

        # Add special key bindings
        self.root.bind('<KeyPress>', self.on_key_press)
        self.root.bind('<KeyRelease>', self.on_key_release)
        self.root.bind('<Button-1>', self.shoot)
        self.root.bind('<Escape>', self.toggle_pause)
        self.root.bind('<F10>', self.toggle_parameters)
        self.root.bind('<F11>', self.toggle_fullscreen)
        self.root.bind('b', self.toggle_boss_mode)
        
    def on_key_press(self, event):
        """Handle key press events with WASD controls"""
        # WASD move system
        key = event.keysym.lower()
        if key in {'w','a','s','d'}:
            self.pressed_keys.add(key)
        # Cheat code input
        if key.isalpha():
            self.cheat_input += key
            self.check_cheat_code()

    def check_cheat_code(self):
        for code, effect in self.cheat_codes.items():
            if effect in self.cheat_input.lower():
                self.activate_cheat(code)
                self.cheat_input = ""
                return
            
            if len(self.cheat_input) > 20:
                self.cheat_input = ""

    def activate_cheat(self, code):
        current_time = time.time()
        
        if code == "godmode":
            self.god_mode = not self.god_mode
            self.shield_active = self.god_mode
            if self.god_mode:
                self.shield_end_time = float('inf')
                self.show_cheat_message("God Mode: ON")
            else:
                self.shield_end_time = current_time
                self.show_cheat_message("God Mode: OFF")
        elif code =="rapidfire":
            self.rapid_fire = not self.rapid_fire
            if self.rapid_fire:
                self.shooting_cooldown = 0.01
                self.show_cheat_message("Rapid Fire: ON")
            else:
                self.shooting_cooldown = 0.5
                self.show_cheat_message("Rapid Fire: OFF")
        
        elif code == "powerup":
            self.shield_active = True
            self.shield_end_time = float('inf')
            self.current_speed = self.base_speed * 1.5
            self.speed_boost_end_time = float('inf')
            self.score_multiplier = 2
            self.score_multiplier_end_time = float('inf')
            self.weapon_type = "double"
            self.weapon_end_time = float('inf')
            self.show_cheat_message("All Power-ups Activated")

        elif code == "points":
            self.score += 1000
            self.show_cheat_message("+1000 points")
        
        elif code == "speedup":
            self.base_speed = min(self.base_speed + 2, 15)
            self.current_speed = self.base_speed
            self.show_cheat_message("Speed Increased")

    def show_cheat_message(self, message):
        cheat_message = tk.Toplevel(self.root)
        cheat_message.overrideredirect(True)
        cheat_message.attributes('-topmost', True)

        cheat_message_width = 200
        cheat_message_height = 40
        x = (self.screen_width - cheat_message_width) // 2
        y = (self.screen_height - cheat_message_height) // 2
        cheat_message.geometry(f"{cheat_message_width}x{cheat_message_height}+{x}+{y}")

        label = tk.Label(
            cheat_message,
            text=message,
            font=('Arial', 12, 'bold'),
            bg='black',
            fg='yellow',
            padx=10,
            pady=5
        )
        label.pack(expand=True, fill=tk.BOTH)

        self.root.after(2000, cheat_message.destroy)

    def on_key_release(self, event):
        """Handle key release events with WASD controls"""
        key = event.keysym.lower()
        if key in {'w','a','s','d'}:
            self.pressed_keys.discard(key)

    def update_movement(self):
        """Update player movement with WASD controls"""
        if 'a' in self.pressed_keys:
            self.velocity_x = max(self.velocity_x - self.acceleration, -1.0)
        elif 'd' in self.pressed_keys:
            self.velocity_x = min(self.velocity_x + self.acceleration, 1.0)
        else:
            self.velocity_x *= self.friction

        if 'w' in self.pressed_keys:
            self.velocity_y = max(self.velocity_y - self.acceleration, -1.0)
        elif 's' in self.pressed_keys:
            self.velocity_y = min(self.velocity_y + self.acceleration, 1.0)
        else:
            self.velocity_y *= self.friction

        if abs(self.velocity_x) > 0.01 or abs(self.velocity_y) > 0.01:
            self.move_player(
                self.velocity_x * self.current_speed,
                self.velocity_y * self.current_speed
            )

    def toggle_fullscreen(self, event=None):
        """Toggle fullscreen mode"""
        is_fullscreen = self.root.attributes('-fullscreen')
        self.root.attributes('-fullscreen', not is_fullscreen)

    def toggle_boss_mode(self, event=None):
        """Toggle boss mode (fake spreadsheet)"""
        if not self.is_boss_mode:
            self.is_paused = True
            
            self.boss_window = tk.Toplevel(self.root)
            self.boss_window.attributes('-fullscreen', True)
            
            spreadsheet_frame = tk.Frame(self.boss_window, bg='white')
            spreadsheet_frame.pack(fill=tk.BOTH, expand=True)
            
            # Add fake spreadsheet content
            tk.Label(spreadsheet_frame, 
                    text="Annual Financial Report 2024",
                    font=('Arial', 24, 'bold'),
                    bg='white').pack(pady=30)
                    
            # Create table
            table_frame = tk.Frame(spreadsheet_frame, bg='white')
            table_frame.pack(pady=20)
            
            cols = ['Quarter', 'Revenue', 'Expenses', 'Profit', 'Growth']
            data = [
                ['Q1 2024', '$150,000', '$90,000', '$60,000', '+15%'],
                ['Q2 2024', '$180,000', '$100,000', '$80,000', '+20%'],
                ['Q3 2024', '$165,000', '$95,000', '$70,000', '+18%'],
                ['Q4 2024', '$200,000', '$110,000', '$90,000', '+22%']
            ]
            
            # Headers
            for i, col in enumerate(cols):
                tk.Label(table_frame, text=col, font=('Arial', 14, 'bold'),
                        bg='lightgray', width=15, height=2).grid(row=0, column=i, padx=2, pady=2)
            
            # Data
            for i, row in enumerate(data):
                for j, value in enumerate(row):
                    tk.Label(table_frame, text=value, font=('Arial', 14),
                            bg='white', width=15, height=2).grid(row=i+1, column=j, padx=2, pady=2)
            
            self.is_boss_mode = True
            
            # Add bindings
            self.boss_window.protocol("WM_DELETE_WINDOW", lambda: None)
            self.boss_window.bind('b', self.toggle_boss_mode)
            self.boss_window.focus_set()
            
        else:
            if hasattr(self, 'boss_window'):
                self.boss_window.destroy()
            self.is_boss_mode = False
            self.is_paused = False

    def toggle_pause(self, event=None):
        """Toggle game pause state"""
        self.is_paused = not self.is_paused
        
        if self.is_paused and not self.is_boss_mode:
            self.show_pause_menu()
        else:
            if self.pause_menu:
                self.pause_menu.destroy()
                self.pause_menu = None

    def toggle_parameters(self, event=None):
        self.show_parameters = not self.show_parameters
    
    def draw_parameters(self):
        if not self.show_parameters:
            return
        
        self.canvas.create_text(
            20, 60, anchor='nw',
            text=f'Position: ({int(self.player_world_x)}, {int(self.player_world_y)}) ',
            fill='white',
            font=('Arial', 14)
        )

        self.canvas.create_text(
            20, 90, anchor='nw',
            text='Red: Chase   Yellow: Avoid   Orange: Circle',
            fill='white',
            font=('Arial', 14)
        )
        
        self.canvas.create_text(
            20, 120, anchor='nw',
            text='Green Item: Shield(10s)   Cyan Item: Speed(5s)   Pink Item: Double Score(8s)',
            fill='white',
            font=('Arial', 14)
        )
        
        self.canvas.create_text(
            20, 150, anchor='nw',
            text='Left Click: Shoot (Cooldown: 0.5s)   ESC: Pause Game   B: Boss Key   F10: Show Parameters   F11: Fullscreen',
            fill='white',
            font=('Arial', 14)
        )      

    def show_pause_menu(self):
        """Show pause menu window"""
        # Create pause menu window
        self.pause_menu = tk.Toplevel(self.root)
        self.pause_menu.title("Game Paused")
        
        # Set window size and position
        window_width = 300
        window_height = 400
        x = (self.screen_width - window_width) // 2
        y = (self.screen_height - window_height) // 2
        self.pause_menu.geometry(f"{window_width}x{window_height}+{x}+{y}")
        
        # Set window style
        self.pause_menu.configure(bg='black')
        self.pause_menu.transient(self.root)
        
        # Create title label
        title_label = tk.Label(
            self.pause_menu,
            text="Game Paused",
            font=('Arial', 24, 'bold'),
            bg='black',
            fg='white'
        )
        title_label.pack(pady=30)
        
        # Button style configuration
        button_width = 18
        button_height = 2
        button_font = ('Arial', 12)
        button_pady = 15
        
        # Continue game button
        resume_button = tk.Button(
            self.pause_menu,
            text="Continue Game",
            width=button_width,
            height=button_height,
            font=button_font,
            command=self.toggle_pause,
            bg='gray20',
            fg='white'
        )
        resume_button.pack(pady=button_pady)
        
        # Restart button
        restart_button = tk.Button(
            self.pause_menu,
            text="Restart Game",
            width=button_width,
            height=button_height,
            font=button_font,
            command=self.restart_game,
            bg='gray20',
            fg='white'
        )
        restart_button.pack(pady=button_pady)
        
        # Exit button
        quit_button = tk.Button(
            self.pause_menu,
            text="Exit to Menu",
            width=button_width,
            height=button_height,
            font=button_font,
            command=self.quit_to_menu,
            bg='gray20',
            fg='white'
        )
        quit_button.pack(pady=button_pady)
        
        # Prevent window close button
        self.pause_menu.protocol("WM_DELETE_WINDOW", lambda: None)
        
        # Set focus
        self.pause_menu.focus_set()

    def restart_game(self):
        """Restart the game"""
        if self.menu:
            self.cleanup_and_return()
            self.menu.start_game()

    def quit_to_menu(self):
        """Quit to main menu"""
        if self.menu:
            self.cleanup_and_return()

    def get_player_name(self):
        """Get player name input window"""
        name_window = tk.Toplevel(self.root)
        name_window.title("Enter Player Name")
        
        # Set window size and position
        window_width = 400
        window_height = 200
        x = (self.screen_width - window_width) // 2
        y = (self.screen_height - window_height) // 2
        name_window.geometry(f"{window_width}x{window_height}+{x}+{y}")
        
        name_window.transient(self.root)
        name_window.configure(bg='black') 
        
        def submit_name():
            name = name_entry.get().strip()
            if name:
                self.player_name = name
                name_window.destroy()
            else:
                tk.messagebox.showwarning("Warning", "Please enter a valid name!")
        
        # Create input box and label
        tk.Label(
            name_window, 
            text="Enter your name:",
            font=('Arial', 16),
            bg='black',
            fg='white'
        ).pack(pady=20)
        
        name_entry = tk.Entry(name_window, font=('Arial', 14))
        name_entry.pack(pady=10)
        
        # Submit button
        tk.Button(
            name_window,
            text="Start Game",
            command=submit_name,
            font=('Arial', 12),
            width=15,
            height=2,
            bg='gray20',
            fg='white'
        ).pack(pady=20)
        
        # Keep window on top and wait for it
        name_window.grab_set()
        self.root.wait_window(name_window)
    
    def update_difficulty(self):
        """Update game difficulty based on score"""
        total_score = self.score +self.survival_score
        self.difficulty_scale = 1.0 + (total_score // self.score_threshold) * 0.1
        current_max_obstacles = min(
            self.max_obstacle_count,
            int(self.base_obstacle_count * self.difficulty_scale)
        )
        if len(self.obstacles) < current_max_obstacles:
            self.generate_obstacles()
        for obstacle in self.obstacles:
            if 'base_speed' not in obstacle:
                obstacle['base_speed'] = obstacle['speed']
            obstacle['speed'] = obstacle['base_speed'] * min(2.0, self.difficulty_scale)

    def draw_background(self):
        """Draw scrolling background"""
        if self.background_photo:
            bg_x = int(-(self.map_offset_x % self.background_photo.width()))
            bg_y = int(-(self.map_offset_y % self.background_photo.height()))

        for x in range(int(bg_x - self.background_photo.width()), 
                    self.canvas_width, 
                    self.background_photo.width()):
            for y in range(int(bg_y - self.background_photo.height()),
                        self.canvas_height,
                        self.background_photo.height()):
                self.canvas.create_image(x, y, image=self.background_photo, anchor='nw')

    def save_leaderboard(self, score):
        """Save score to leaderboard"""
        try:
            leaderboard = []
            try:
                with open('leaderboard.txt', 'r', encoding='utf-8') as f:
                    for line in f:
                        if line.strip():
                            name, score_str = line.strip().split(',')
                            leaderboard.append((name, int(score_str)))
            except FileNotFoundError:
                pass

            leaderboard.append((self.player_name, score))
            leaderboard.sort(key=lambda x: x[1], reverse=True)
            leaderboard = leaderboard[:10]
            
            with open('leaderboard.txt', 'w', encoding='utf-8') as f:
                for name, score in leaderboard:
                    f.write(f"{name},{score}\n")
                    
            return leaderboard
        except Exception as e:
            print(f"Error saving leaderboard: {e}")
            return []

    def show_leaderboard(self):
        if self.menu:
            self.menu.show_leaderboard()

    def shoot(self, event):
        """Handle shooting event"""
        current_time = time.time()
        if current_time - self.last_shot_time < self.shooting_cooldown:
            return
            
        self.last_shot_time = current_time
    
        mouse_x = event.x
        mouse_y = event.y
        dx = mouse_x - self.player_x
        dy = mouse_y - self.player_y
    
        length = math.sqrt(dx * dx + dy * dy)
        if length > 0:
            dx = dx / length
            dy = dy / length

        perpendicular_dx = -dy
        perpendicular_dy = -dx

        if self.weapon_type == "double":
    
            bullet1 = {
                'x': self.player_world_x + perpendicular_dx * self.double_shot_offset,
                'y': self.player_world_y + perpendicular_dy * self.double_shot_offset,
                'dx': dx * self.bullet_speed,
                'dy': dy * self.bullet_speed,
                'damage': self.bullet_damage,
                'lifetime': 2.0,
                'created_time': current_time,
                'piercing': self.weapon_type == "pierce"
        }

            bullet2 = {
                'x': self.player_world_x - perpendicular_dx * self.double_shot_offset,
                'y': self.player_world_y - perpendicular_dy * self.double_shot_offset,
                'dx': dx * self.bullet_speed,
                'dy': dy * self.bullet_speed,
                'damage': self.bullet_damage,
                'lifetime': 2.0,
                'created_time': current_time,
                'piercing': self.weapon_type == "pierce"
        }
            
            self.bullets.extend([bullet1, bullet2])
        else:
            bullet = {
                'x': self.player_world_x,
                'y': self.player_world_y,
                'dx': dx * self.bullet_speed,
                'dy': dy * self.bullet_speed,
                'damage': self.bullet_damage,
                'lifetime': 2.0,
                'created_time': current_time,
                'piercing': self.weapon_type == "pierce"
        }
        self.bullets.append(bullet)

        # Double shot
        if self.weapon_type == "double":
            if current_time - self.last_double_shot >= self.double_shot_delay:
                self.last_double_shot = current_time
                bullet2 = bullet.copy()
                bullet2['created_time'] = current_time + self.double_shot_delay
                self.bullets.append(bullet2)

    def update_bullets(self):
        """Update all bullets"""
        current_time = time.time()
        surviving_bullets = []
        for bullet in self.bullets:
            bullet['x'] += bullet['dx']
            bullet['y'] += bullet['dy']
        
            hit = False
            for obstacle in self.obstacles[:]:
                screen_ox = obstacle['x'] - self.map_offset_x
                screen_oy = obstacle['y'] - self.map_offset_y
                bullet_screen_x = bullet['x'] - self.map_offset_x
                bullet_screen_y = bullet['y'] - self.map_offset_y

                distance = math.sqrt((bullet_screen_x - screen_ox)**2 + (bullet_screen_y - screen_oy)**2)
                if distance < (self.obstacle_size + self.bullet_size) / 2:
                    hit = True
                    self.obstacles.remove(obstacle)
                    self.score += 20 * self.score_multiplier
                    if not bullet['piercing']:  # Only break if not piercing
                        break
        
            if (not hit or bullet['piercing']) and current_time - bullet['created_time'] < bullet['lifetime']:
                surviving_bullets.append(bullet)
    
        self.bullets = surviving_bullets

    def draw_bullets(self):
        """Draw all bullets"""
        for bullet in self.bullets:
            screen_x = bullet['x'] - self.map_offset_x
            screen_y = bullet['y'] - self.map_offset_y
            
            distance = math.sqrt((screen_x - self.player_x)**2 + (screen_y - self.player_y)**2)
            if distance <= self.visible_radius:
                self.canvas.create_oval(
                    screen_x - self.bullet_size/2,
                    screen_y - self.bullet_size/2,
                    screen_x + self.bullet_size/2,
                    screen_y + self.bullet_size/2,
                    fill='yellow'
                )

    def update_survival_score(self):
        """Update survival score based on time"""
        current_time = time.time()
        survival_time = current_time - self.start_time
        self.survival_score = int(survival_time * self.survival_score_rate)

    def generate_initial_items(self):
        """Generate initial items when game starts"""
        for _ in range(10):
            self.spawn_item()

    def spawn_item(self):
        """Spawn a new item with random type and position"""
        item = {
            'x': random.randint(0, self.map_size),
            'y': random.randint(0, self.map_size),
            'type': random.choice(['shield', 'speed', 'points', 'double', 'pierce', 'large']),
            'collected': False
        }
        self.items.append(item)

    def activate_item_effect(self, item_type):
        """Activate effect based on item type"""
        current_time = time.time()

        if item_type == 'shield':
            self.shield_active = True
            self.shield_end_time = current_time + 10
        elif item_type == 'speed':
            self.current_speed = self.base_speed * 1.5
            self.speed_boost_end_time = current_time + 5
        elif item_type == 'points':
            self.score_multiplier = 2
            self.score_multiplier_end_time = current_time + 8
        elif item_type == 'double':
            self.weapon_type = "double"
            self.weapon_end_time = current_time + 8
        elif item_type == 'pierce':
            self.weapon_type = "pierce"
            self.weapon_end_time = current_time + 8  
        elif item_type == 'large':
            self.weapon_type = "large"
            self.bullet_size = 12
            self.weapon_end_time = current_time + 8

    def update_effects(self):
        """Update all active effects"""
        current_time = time.time()
    
        if self.shield_active and current_time > self.shield_end_time:
            self.shield_active = False
    
        if current_time > self.speed_boost_end_time:
            self.current_speed = self.base_speed
    
        if current_time > self.score_multiplier_end_time:
            self.score_multiplier = 1
        
        if current_time > self.weapon_end_time:
            self.weapon_type = "normal"
            self.bullet_size = 6

    def check_item_collection(self):
        """Check if player has collected any items"""
        for item in self.items:
            if item['collected']:
                continue
                
            screen_ix = item['x'] - self.map_offset_x
            screen_iy = item['y'] - self.map_offset_y
            
            distance = math.sqrt((screen_ix - self.player_x)**2 + (screen_iy - self.player_y)**2)
            
            if distance < (self.player_size + self.item_size) / 2:
                item['collected'] = True
                self.activate_item_effect(item['type'])
                self.score += 10 * self.score_multiplier
                
        self.items = [item for item in self.items if not item['collected']]

    def generate_obstacles(self):
        """Generate new obstacles"""
        total_score = self.score + self.survival_score
    
        current_max_obstacles = min(
            self.max_obstacle_count,
            int(self.base_obstacle_count * self.difficulty_scale)
        )
    
        num_to_generate = current_max_obstacles - len(self.obstacles)
    
        for _ in range(num_to_generate):
            while True:
                x = random.randint(0, self.map_size)
                y = random.randint(0, self.map_size)
                dx = x - self.player_world_x
                dy = y - self.player_world_y
                distance = math.sqrt(dx * dx + dy * dy)
                if distance > 300:  
                    break
                
            base_speed = random.uniform(1, 3)
            obstacle = {
                'x': x,
                'y': y,
                'base_speed': base_speed,
                'speed': base_speed * min(2.0, self.difficulty_scale),
                'behavior': random.choice(['chase', 'avoid', 'circle']),
                'angle': random.uniform(0, 2 * math.pi)
            }
            self.obstacles.append(obstacle)

    def move_player(self, dx, dy):
        """Move player and update map offset with edge movement"""
        # Calculate new positions
        new_x = self.player_x + dx
        new_y = self.player_y + dy

        self.player_world_x += dx
        self.player_world_y += dy
    
        # Constrain to world bounds
        self.player_world_x = max(0, min(self.map_size, self.player_world_x))
        self.player_world_y = max(0, min(self.map_size, self.player_world_y))
    
        # Update map offset for scrolling
        if new_x < 100:  # Left edge
            self.map_offset_x = max(0, self.player_world_x - 100)
        elif new_x > self.canvas_width - 100:  # Right edge
            self.map_offset_x = min(self.map_size - self.canvas_width, self.player_world_x - self.canvas_width + 100)
        
        if new_y < 100:  # Top edge
            self.map_offset_y = max(0, self.player_world_y - 100)
        elif new_y > self.canvas_height - 100:  # Bottom edge
            self.map_offset_y = min(self.map_size - self.canvas_height, self.player_world_y - self.canvas_height + 100)
    
        # Update player screen position
        self.player_x = self.player_world_x - self.map_offset_x
        self.player_y = self.player_world_y - self.map_offset_y

    def update_obstacles(self):
        """Update positions of all obstacles"""
        for obstacle in self.obstacles:
            dx = self.player_world_x - obstacle['x']
            dy = self.player_world_y - obstacle['y']
            distance = math.sqrt(dx * dx + dy * dy)
        
            if distance < 2:
                continue
            
            if obstacle['behavior'] == 'chase':
                obstacle['x'] += (dx / distance) * obstacle['speed']
                obstacle['y'] += (dy / distance) * obstacle['speed']
            
            elif obstacle['behavior'] == 'avoid':
                obstacle['x'] -= (dx / distance) * obstacle['speed']
                obstacle['y'] -= (dy / distance) * obstacle['speed']
            
            elif obstacle['behavior'] == 'circle':
                obstacle['angle'] += 0.02
                center_x = self.player_world_x + math.cos(obstacle['angle']) * 100
                center_y = self.player_world_y + math.sin(obstacle['angle']) * 100
            
                dx = center_x - obstacle['x']
                dy = center_y - obstacle['y']
                dist = math.sqrt(dx * dx + dy * dy)
                if dist > 0:
                    obstacle['x'] += (dx / dist) * obstacle['speed']
                    obstacle['y'] += (dy / dist) * obstacle['speed']
            
            obstacle['x'] = max(0, min(self.map_size, obstacle['x']))
            obstacle['y'] = max(0, min(self.map_size, obstacle['y']))

    def is_collision(self, x, y):
        """Check if player collides with any obstacle"""
        if self.shield_active or self.god_mode:
            return False
            
        player_rect = (x - self.player_size/2, y - self.player_size/2,
                      x + self.player_size/2, y + self.player_size/2)
        
        for obstacle in self.obstacles:
            screen_ox = obstacle['x'] - self.map_offset_x
            screen_oy = obstacle['y'] - self.map_offset_y
            
            obstacle_rect = (screen_ox - self.obstacle_size/2, screen_oy - self.obstacle_size/2,
                           screen_ox + self.obstacle_size/2, screen_oy + self.obstacle_size/2)
            
            if not (player_rect[2] < obstacle_rect[0] or
                   player_rect[0] > obstacle_rect[2] or
                   player_rect[3] < obstacle_rect[1] or
                   player_rect[1] > obstacle_rect[3]):
                return True
        return False
    

    def draw_items(self):
        """Draw all items in visible range"""
        for item in self.items:
            if item['collected']:
                continue
                
            screen_ix = item['x'] - self.map_offset_x
            screen_iy = item['y'] - self.map_offset_y
            
            distance = ((screen_ix - self.player_x) ** 2 + (screen_iy - self.player_y) ** 2) ** 0.5
            if distance <= self.visible_radius:
                color = {
                    'shield': '#00FF00',
                    'speed': '#00FFFF',
                    'points': '#FF00FF',
                    'double': '#FFA500',  
                    'pierce': '#FF0000',  
                    'large': '#800080'    
                }[item['type']]
                
                self.canvas.create_oval(
                    screen_ix - self.item_size/2, screen_iy - self.item_size/2,
                    screen_ix + self.item_size/2, screen_iy + self.item_size/2,
                    fill=color
                )

    def draw_status_effects(self):
        margin = 10
        padding = 10
        y_start = 90
        x_start = margin
        line_height = 25
        
        current_time = time.time()
        status_items = []
        
        if self.god_mode:
            status_items.append(('God Mode', 'ACTIVE', 'yellow', None))
            
        if self.rapid_fire:
            status_items.append(('Rapid Fire', 'ACTIVE', 'yellow', None))
            
        if self.shield_active and self.shield_end_time != float('inf'):
            remaining = max(0, self.shield_end_time - current_time)
            status_items.append(('Shield', f'{remaining:.1f}s', '#00FF00', None))
            
        if current_time <= self.speed_boost_end_time:
            remaining = max(0, self.speed_boost_end_time - current_time)
            status_items.append(('Speed Boost', f'{remaining:.1f}s', '#00FFFF', None))
            
        if self.score_multiplier > 1:
            remaining = max(0, self.score_multiplier_end_time - current_time)
            status_items.append(('Double Score', f'{remaining:.1f}s', '#FF00FF', None))
            
        if current_time <= self.weapon_end_time:
            remaining = max(0, self.weapon_end_time - current_time)
            weapon_text = {
                'double': 'Double Shot',
                'pierce': 'Pierce Shot',
                'large': 'Large Shot'
            }.get(self.weapon_type, '')
            if weapon_text:
                status_items.append((weapon_text, f'{remaining:.1f}s', '#FFA500', None))
                
        if not status_items:
            return
            
        max_name_width = max(len(item[0]) for item in status_items) * 8
        max_value_width = max(len(str(item[1])) for item in status_items) * 8
        box_width = max_name_width + max_value_width + padding * 3
        box_height = len(status_items) * line_height + padding * 2
        
        self.canvas.create_rectangle(
            x_start, y_start,
            x_start + box_width, y_start + box_height,
            fill='black', stipple='gray50',  
            outline='#333333' 
        )
        
        current_y = y_start + padding
        for name, value, color, _ in status_items:
            self.canvas.create_text(
                x_start + padding,
                current_y,
                text=name,
                fill='white',
                anchor='nw',
                font=('Arial', 12)
            )
            
            self.canvas.create_text(
                x_start + box_width - padding,
                current_y,
                text=value,
                fill=color,
                anchor='ne',
                font=('Arial', 12, 'bold')
            )
            
            current_y += line_height

    def update_game(self):
        """Main game loop"""
        if not self.is_paused:
            self.update_movement()
            self.update_obstacles()
            self.update_bullets()
            self.check_item_collection()
            self.update_effects()
            self.update_survival_score()
            self.update_difficulty()
            
            self.item_spawn_timer += 1
            if self.item_spawn_timer >= self.item_spawn_interval:
                self.spawn_item()
                self.item_spawn_timer = 0
            
            if len(self.obstacles) < 10:
                self.generate_obstacles()
            
            self.canvas.delete('all')
            self.draw_background()
            
            for r in range(self.visible_radius, 0, -2):
                alpha = int(255 * (1 - r/self.visible_radius))
                color = f'#{alpha:02x}{alpha:02x}{alpha:02x}'
                self.canvas.create_oval(
                    self.player_x - r, self.player_y - r,
                    self.player_x + r, self.player_y + r,
                    fill='', outline=color
                )
            
            self.draw_items()
            self.draw_bullets()
            
            for obstacle in self.obstacles:
                screen_ox = obstacle['x'] - self.map_offset_x
                screen_oy = obstacle['y'] - self.map_offset_y
                
                distance = ((screen_ox - self.player_x) ** 2 + (screen_oy - self.player_y) ** 2) ** 0.5
                if distance <= self.visible_radius:
                    color = {
                        'chase': 'red',
                        'avoid': 'yellow',
                        'circle': 'orange'
                    }[obstacle['behavior']]
                    
                    self.canvas.create_rectangle(
                        screen_ox - self.obstacle_size/2, screen_oy - self.obstacle_size/2,
                        screen_ox + self.obstacle_size/2, screen_oy + self.obstacle_size/2,
                        fill=color
                    )
            
            player_color = 'green'
            if self.shield_active:
                self.canvas.create_oval(
                    self.player_x - self.player_size/2 - 5,
                    self.player_y - self.player_size/2 - 5,
                    self.player_x + self.player_size/2 + 5,
                    self.player_y + self.player_size/2 + 5,
                    fill='', outline='#00FF00', width=2
                )
            
            self.canvas.create_oval(
                self.player_x - self.player_size/2,
                self.player_y - self.player_size/2,
                self.player_x + self.player_size/2,
                self.player_y + self.player_size/2,
                fill=player_color
            )
            
            total_score = self.score + self.survival_score
            self.canvas.create_text(
                20, 20, anchor='nw',
                text=f'Total Score: {total_score} (Game: {self.score} + Survival: {self.survival_score})',
                fill='white',
                font=('Arial', 20)
            )
            
            self.draw_parameters()
            self.draw_status_effects()
            
            # Check for game over
            if self.is_collision(self.player_x, self.player_y):
                self.game_over()
            else:
                self.root.after(16, self.update_game)
        else:
            # Continue checking game loop while paused
            self.root.after(16, self.update_game)

    def game_over(self):
        """Handle game over"""
        total_score = self.score + self.survival_score
        self.save_leaderboard(total_score)
        
        self.canvas.create_text(
            self.canvas_width/2, self.canvas_height/2,
            text=f"Game Over! Collision with obstacle!\n"
                 f"Final Score: {total_score}\n"
                 f"(Game: {self.score} + Survival: {self.survival_score})",
            fill='red',
            font=('Arial', 36)
        )
        
        self.show_leaderboard()
        self.root.after(2000, self.cleanup_and_return)

    def cleanup_and_return(self):
        """Clean up game window and return to menu"""
        if hasattr(self, 'boss_window') and self.boss_window:
            self.boss_window.destroy()
        self.root.destroy()
        if self.menu:
            self.menu.return_to_menu()

    def run(self):
        """Start the game"""
        self.update_game()
        self.root.mainloop()

# Start the application
if __name__ == "__main__":
    menu = MainMenu()
    menu.run()