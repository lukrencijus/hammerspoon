# Better Force Quit Applications 

`modules/force_quit.lua`

This was written because I do not like "task managers" on macOS. We have "Force Quit Applications" (cmd + option + esc) but it is very basic and limited. We also have "Activity Monitor" but it takes a while to load. So this script has a customizable hotkey to open it, includes search functionality and also shows background applications.

![sw 2025-05-29 at 11 58 42](https://github.com/user-attachments/assets/6eac12b1-3853-4f22-8412-e5a6c50313cc)

# Spotify in menu bar

`modules/spotify.lua`

This script was written so no third party application would be needed on system. It shows artist and song name, media controls when clicked and hides when Spotify is not open.

![sw 2025-05-29 at 12 00 06](https://github.com/user-attachments/assets/0b688bf1-609f-441c-832f-f4c16fed560b)



![sw 2025-05-29 at 12 00 16](https://github.com/user-attachments/assets/875776ef-57e1-48fd-acc2-1765da537d15)

# Unsplash Daily Wallpaper

`modules/wallpaper.lua`

Sometimes it just becomes boring to look at the same wallpaper. This script automatically updates macOS wallpaper with a random photo from Unsplash. Fetches a new wallpaper every 20 hours. Applies to all connected displays. Deletes wallpaper files automatically. Taken from curated collections ([Wallpapers for macOS](https://unsplash.com/collections/7282015), [Photo of the Day](https://unsplash.com/collections/1459961), [Unsplash Editorial](https://unsplash.com/collections/317099), [Wallpapers](https://unsplash.com/collections/1065976)).

> [!IMPORTANT]
> Add [Unsplash API Access Key](https://unsplash.com/developers) to the `secrets.lua`

# Automatic Window Focus Switcher

`modules/window_focus.lua`

On macOS when you minimize an application window it does not automatically cycle your active focus to another window, so when you minimize a window, this script retrieves all other open windows and immediately shifts focus to the next available visible window.

# Menu Bar App Launch Indicator

`modules/launch_indicator.lua`

On macOS if you hide your dock and launch applications using keyboard shortcuts, it can sometimes feel unresponsive, you press a hotkey but nothing happens, forcing you to hover your mouse over the screen edge to check if the application is actually loading, so this script displays a temporary loading icon and the application's name in macOS menu bar.
