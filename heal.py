import math, time, random, pygetwindow
import win32gui
from serial import Serial
from ctypes import windll
from pynput.mouse import Listener, Controller
from _thread import start_new_thread
from http.server import HTTPServer, BaseHTTPRequestHandler
from io import BytesIO

### CONSTANTS ###

TARGET_ENCODE_START = 58

CONTROL_ENCODE_VALUE = 1024
ALT_ENCODE_VALUE = 2048
SHIFT_ENCODE_VALUE = 4096

LIGHT_SIZE = 4

LIGHT_KEY_COUNT = 1
LIGHT_TARGET_COUNT = 2
LIGHT_ACTION_COUNT = 2

TARGET_LIGHT_PLAYER_VALUE = 1
TARGET_LIGHT_PARTY_VALUE = 2
TARGET_LIGHT_FOCUS_VALUE = 7
TARGET_LIGHT_RAID_VALUE = 8

TARGET_INTERACT_TARGET_VALUE = 9
TARGET_INTERACT_ACTION_VALUE = 0x36

LIGHT_ACTION_VALUES = {
	0: 21, # r - "Light"
	1: 33, # 4 - "Flash"
	2: 45, # = - "Blessing"
	3: 46, # - - "BlessingAlt"
	4: 32, # 3 - "Cleanse"
	5: SHIFT_ENCODE_VALUE + 10, # SHIFT + G - "Drink"
	6: 39, # 0 - "Follow"
	7: 44, #   - "Jump",
	8: SHIFT_ENCODE_VALUE + 33, # SHIFT + 4 - "Light Flash"
	9: CONTROL_ENCODE_VALUE + 32, # SHIFT + 3 - "Light Light Flash"
  10: 37, # 8 - "Res"
  11: 11, # h - "Mount"

  12: CONTROL_ENCODE_VALUE + 9, # F

  # unimplimented
  13: SHIFT_ENCODE_VALUE + 23, # SHIFT + t - "Blessing of Protection"
  14: SHIFT_ENCODE_VALUE + 8, # SHIFT + e - "Divine Shield"

	15: -1, # "Nothing"
}
FORCE_OVERRIDE_INDEXES = [
  4, 13, 14
]
STATIONARY_ACTION_INDEXES = [
  0, 1, 5, 8, 9, 10, 11
]
INTERACT_ACTION_INDEXES = [
  12
]
FORCE_COMMAND_DICTIONARY = {
  "Follow": 38,
  "OnlyFollow": CONTROL_ENCODE_VALUE + 38,
  "Buff": ALT_ENCODE_VALUE + 38,
  "Tank": SHIFT_ENCODE_VALUE + 38,
  "Aoe": CONTROL_ENCODE_VALUE + ALT_ENCODE_VALUE + 38
}

PIXEL_VALUE_THRESHOLD = 0.5 * 0xFF

GCD_THRESHOLD = 1.44
MOUSE_MOVE_IGNORE = 3.00

WINDOW_SWAP_FOCUS_THRESHOLD = 0.5

### GLOBAL VARIABLES ###
currentTime = time.time()

activeWindows = []
currentActiveWindow = None

overrideLock = False
overrideLastUpdateTime = time.time()

### SERIAL INTERFACE ###
dc = windll.user32.GetDC(0)
arduino = Serial('COM4', 9600, timeout=.1)

def getTargetModifier(v):
  modifierValues = 0
  sequenceIndex = v % 8

  if (sequenceIndex >= 5 or sequenceIndex == 1):
    modifierValues += CONTROL_ENCODE_VALUE
  
  if (sequenceIndex == 7 or sequenceIndex == 5 or sequenceIndex == 4 or sequenceIndex == 2):
    modifierValues += SHIFT_ENCODE_VALUE
  
  if (sequenceIndex >= 6 or sequenceIndex == 4 or sequenceIndex == 3):
    modifierValues += ALT_ENCODE_VALUE

  return modifierValues

def targetIndexToSerial(v):
  # print('target index:' + str(v))
  # player values = 0, 1, 2
  # party values = 4, 5, 6, 7, 8, 9
  retValue = 0
  if (v >= 2 and v < TARGET_LIGHT_RAID_VALUE):
    partyEncode = 0x37
    # in party
    print("EC: " + str(v))
    partyValue = v - 2
    modifierValues = getTargetModifier(partyValue)

    return partyEncode + modifierValues
    
  elif (v >= TARGET_LIGHT_RAID_VALUE):
    raidEncodes = [
      0x2f,
      0x30,
      0x33,
      0x34,
      0x38
    ]
    raidValue = v - TARGET_LIGHT_RAID_VALUE
    modifierValues = getTargetModifier(raidValue)

    raidKey = math.floor(raidValue / 8)

    return raidEncodes[raidKey] + modifierValues

  return TARGET_ENCODE_START + retValue

def writeToSerial(v):
  if checkAndForceCurrentWindowFocus():
    print("WS: " + str(v))
    arduino.write(str(v).encode())
    arduino.readline()

def writeMouseToSerial(x, y, skipForce=False):
  global overrideLock

  if skipForce or checkAndForceCurrentWindowFocus():
    print("MS: " + str(x) + " : " + str(y))
    mouse.position = (x, y)
    doSleep(0.025)
    arduinoString = "m0,0"
    
    overrideLock = True
    
    arduino.write(arduinoString.encode())
    arduino.readline()
    doSleep(0.025)

    overrideLock = False

def doSleep(d):
  global currentTime

  time.sleep(d)
  currentTime = time.time()

### PIXEL READING ###

def getPixel(x, y):
  pixelBase = windll.gdi32.GetPixel(dc,x,y)

  r = (pixelBase & 0x0000FF)
  g = (pixelBase & 0x00FF00) >> 8
  b = (pixelBase & 0xFF0000) >> 16

  return (r, g, b)

def getSubPixelValue(startingOffset, pixelCount, bufferLeft = 0, bufferTop = 0):
  pixelValue = 0

  for i in range(pixelCount):
    pixel = getPixel(bufferLeft + (startingOffset + i) * LIGHT_SIZE, bufferTop)

    if (pixel[0] > PIXEL_VALUE_THRESHOLD):
      pixelValue += 2 ** (i * 3 + 0)
    if (pixel[1] > PIXEL_VALUE_THRESHOLD):
      pixelValue += 2 ** (i * 3 + 1)
    if (pixel[2] > PIXEL_VALUE_THRESHOLD):
      pixelValue += 2 ** (i * 3 + 2)

  return pixelValue

def getCurrentTarget():
  return ''

### MOUSE INTERACTION ###
mouse = Controller()

def mouseInteract(x=None, y=None, button=None, pressed=None):
  global overrideLastUpdateTime, overrideLock

  if not overrideLock:
    overrideLastUpdateTime = time.time() + MOUSE_MOVE_IGNORE
  return

def startInteract():
  with Listener(on_click=mouseInteract) as listener:
    listener.join()

start_new_thread(startInteract, ())

### WEBSERVER INTERACTION ###

class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
  def do_GET(self):
    self.send_response(200)
    self.end_headers()
    self.wfile.write(b'')

  def do_POST(self):
    global activeWindows
    
    path = str(self.path)

    if path == "/follow":
      setNextCommand(FORCE_COMMAND_DICTIONARY["Follow"])
    if path == "/buff":
      setNextCommand(FORCE_COMMAND_DICTIONARY["Buff"])
    if path == "/tank":
      setNextCommand(FORCE_COMMAND_DICTIONARY["Tank"])
    if path == "/only_follow":
      setNextCommand(FORCE_COMMAND_DICTIONARY["OnlyFollow"])
    if path == "/aoe":
      setNextCommand(FORCE_COMMAND_DICTIONARY["Aoe"])


    self.send_response(200)
    self.end_headers()
    response = BytesIO()
    response.write(b'success')
    self.wfile.write(response.getvalue())

def startServer():
  httpd = HTTPServer(('', 8069), SimpleHTTPRequestHandler)
  httpd.serve_forever()

start_new_thread(startServer, ())

### WINDOW INTERACTION ###

def isWindowValid(window):
  if window is None or (not win32gui.IsWindowVisible(window)):
    return False

  activeWindowText = win32gui.GetWindowText(window)
  
  if not ((activeWindowText == "World of Warcraft") or (activeWindowText == "*Untitled - Notepad")):
    return False
  
  return True

# Test how many windows we have...

doSleep(1)
class ActiveWindow:
    def __init__(self, window, lastUpdateTime, lastGCDUpdateTime, lastTargetIndex, lastActionIndex, x, y, w, h, index):
      self.window = window
      self.lastUpdateTime = lastUpdateTime
      self.lastGCDUpdateTime = lastGCDUpdateTime
      self.lastTargetIndex = lastTargetIndex
      self.lastActionIndex = lastActionIndex
      self.x = x + 1
      self.y = y + 1
      self.w = w
      self.h = h
      self.nextCommand = None
      self.index = index

def addNewWindow(window):
  cx, cy, cr, cb = win32gui.GetClientRect(window)
  x, y = win32gui.ClientToScreen(window, (cx, cy))

  w = cr - cx
  h = cb - cy
  
  insertBean = ActiveWindow(window, time.time(), time.time(), -2, -2, x, y, w, h, len(activeWindows))

  activeWindows.append(insertBean)

  return insertBean

def winEnumHandler(window, ctx):
  if isWindowValid(window):
    addNewWindow(window)
win32gui.EnumWindows(winEnumHandler, None)
# now we need a few items per window.

def shouldSwap():
  global currentTime, currentActiveWindow, activeWindows
  
  if currentActiveWindow is None:
    return True
  if len(activeWindows) == 1:
    return False
  
  timeSinceUpdate = currentTime - currentActiveWindow.lastUpdateTime
  # check the update time
  print("TU: " + str(timeSinceUpdate))
  if timeSinceUpdate > WINDOW_SWAP_FOCUS_THRESHOLD:
    return False

  return True

def checkAndForceCurrentWindowFocus():
  global currentActiveWindow

  activeWindow = win32gui.GetForegroundWindow()

  if not isWindowValid(activeWindow):
    return False

  if activeWindow != currentActiveWindow.window:
    writeMouseToSerial(currentActiveWindow.x + 50, currentActiveWindow.y - 6, True)
    doSleep(0.05)

  return True

def swapToNextWindow():
  global currentActiveWindow, activeWindows

  if (not currentActiveWindow) or (currentActiveWindow is None):
    if len(activeWindows) == 0:
      doSleep(2)

      return

    currentActiveWindow = activeWindows[0]
    return
  
  print("SP: " + str(currentActiveWindow.index))
  currentActiveWindow = activeWindows[(currentActiveWindow.index + 1) % len(activeWindows)]

def getWindowBean(window):
  focus = next(filter(lambda bean: bean.window == activeWindow, activeWindows), None)
  if not focus:
    focus = addNewWindow(activeWindow)
  return focus

def setNextCommand(command):
  for window in activeWindows:
    window.nextCommand = command

print("RY")
### LOOP
while True:
  if shouldSwap():
    swapToNextWindow()
    
    doSleep(0.25)
    continue

  doSleep((0.05 + (random.random() / 16)) / len(activeWindows))

  lastGCDUpdateTimeCooked = max(currentActiveWindow.lastGCDUpdateTime, overrideLastUpdateTime)
  deltaTimeGCD = currentTime - lastGCDUpdateTimeCooked

  currentActiveWindow.lastUpdateTime = currentTime

  if currentActiveWindow.nextCommand:
    print("NC: " + str(currentActiveWindow.nextCommand))
    writeToSerial(currentActiveWindow.nextCommand)
    
    currentActiveWindow.nextCommand = None
    continue

  currentKeyValue = getSubPixelValue(0, LIGHT_KEY_COUNT, currentActiveWindow.x, currentActiveWindow.y)

  if (currentKeyValue == 0):
    doSleep(0.05)
    continue

  currentActionIndex = getSubPixelValue(LIGHT_KEY_COUNT + LIGHT_TARGET_COUNT, LIGHT_ACTION_COUNT, currentActiveWindow.x, currentActiveWindow.y)

  if (currentActionIndex != -1):
    currentTargetIndex = getSubPixelValue(LIGHT_KEY_COUNT, LIGHT_TARGET_COUNT, currentActiveWindow.x, currentActiveWindow.y)

    print("CA: " + str(currentActionIndex) + " : " + str(currentTargetIndex))

    if ((currentActionIndex == currentActiveWindow.lastActionIndex) and
        (currentTargetIndex == currentActiveWindow.lastTargetIndex)):

      # don't do anything for a bit
      currentActiveWindow.lastTargetIndex = -2  
      currentActiveWindow.lastActionIndex = -2

      doSleep(0.15)

    elif ((currentActionIndex in FORCE_OVERRIDE_INDEXES) or deltaTimeGCD > GCD_THRESHOLD):
      if (not (currentTargetIndex == -1)):
        currentActiveWindow.lastTargetIndex = currentTargetIndex
        writeToSerial(targetIndexToSerial(currentTargetIndex))

        doSleep(0.15 + (random.random() / 20))

        if (currentActionIndex in INTERACT_ACTION_INDEXES):
          writeToSerial(TARGET_INTERACT_TARGET_VALUE)

          doSleep(0.25 + (random.random() / 20))

      if (currentActionIndex in STATIONARY_ACTION_INDEXES):
        writeToSerial(79 + round(random.random()))
        doSleep(0.025 + (random.random() / 20))

      currentActiveWindow.lastActionIndex = currentActionIndex

      writeToSerial(LIGHT_ACTION_VALUES[currentActionIndex])
      currentActiveWindow.lastGCDUpdateTime = currentTime
    
      if (currentActionIndex in INTERACT_ACTION_INDEXES):
        writeToSerial(TARGET_INTERACT_ACTION_VALUE)

        doSleep(0.05 + (random.random() / 20))
