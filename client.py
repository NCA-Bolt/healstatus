from pynput.keyboard import Key, Listener, Key
import requests 

def on_press(key):
  try:
    if key == Key.home:
      API_ENDPOINT = "http://192.168.1.5:8069/follow"
      r = requests.post(url = API_ENDPOINT)
    if key == Key.insert:
      API_ENDPOINT = "http://192.168.1.5:8069/aoe"
      r = requests.post(url = API_ENDPOINT)
    if key == Key.end:
      API_ENDPOINT = "http://192.168.1.5:8069/buff"
      r = requests.post(url = API_ENDPOINT)
    if key == Key.scroll_lock:
      API_ENDPOINT = "http://192.168.1.5:8069/only_follow"
      r = requests.post(url = API_ENDPOINT)
    if key == Key.page_down:
      API_ENDPOINT = "http://192.168.1.5:8069/tank"
      r = requests.post(url = API_ENDPOINT)
  except:
    print("exception thrown")

# Collect events until released
with Listener(on_press=on_press) as listener:
  listener.join()