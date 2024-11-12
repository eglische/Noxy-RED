import paho.mqtt.client as mqtt
from pynput.keyboard import Controller, Key, KeyCode, Listener
import time
import json
import platform

# Set DEBUG mode to True or False to enable/disable debug logs
DEBUG = True

# Initialize the keyboard controller
keyboard = Controller()

# Detect if running on Linux
is_linux = platform.system() == "Linux"

# Load configuration from a JSON file
def load_config():
    with open('config.json', 'r') as config_file:
        return json.load(config_file)

# Load the configuration
config = load_config()

# MQTT settings from config.json
MQTT_BROKER = config["mqtt"]["broker"]
MQTT_PORT = config["mqtt"]["port"]
MQTT_INPUT_TOPIC = config["mqtt"]["input_topic"]
MQTT_OUTPUT_TOPIC = config["mqtt"]["output_topic"]
MQTT_QOS = config["mqtt"]["qos"]

# Track whether the CTRL key is currently pressed
ctrl_pressed = False

# Function to handle keypress combinations using VK codes (adapted for Linux)
def simulate_keystroke(vk_sequence):
    try:
        # Adapt key codes for Linux
        keys_to_press = []
        for vk in vk_sequence:
            if is_linux:
                # Linux may require remapping vk codes or using Key objects directly
                if vk == 96:  # Example: NumPad 0
                    keys_to_press.append(Key.insert)  # Adjust mapping if necessary
                else:
                    keys_to_press.append(KeyCode.from_vk(int(vk)))
            else:
                keys_to_press.append(KeyCode.from_vk(int(vk)))

        # Press keys simultaneously
        for key in keys_to_press:
            keyboard.press(key)

        # Release keys in reverse order
        for key in reversed(keys_to_press):
            keyboard.release(key)

        if DEBUG:
            print(f"Simulated keystroke: {vk_sequence}")
    
    except Exception as e:
        if DEBUG:
            print(f"Error simulating keystroke: {e}")

# Function to capture CTRL + NumPad keys and send to MQTT output topic as a string
def on_press(key):
    global ctrl_pressed
    try:
        # Check if CTRL key is pressed or released
        if key == Key.ctrl_l or key == Key.ctrl_r:
            ctrl_pressed = True
            if DEBUG:
                print("CTRL key pressed")
        # If CTRL is pressed and a NumPad key is pressed, publish it as a string
        elif ctrl_pressed and isinstance(key, KeyCode):
            # Only capture NumPad keys (range 96-111 includes 0-9, divide, multiply, etc.)
            if is_linux:
                if key.vk in range(65456, 65466):  # Adjust for Linux NumPad keycodes
                    vk_code = str(key.vk)
                    client.publish(MQTT_OUTPUT_TOPIC, vk_code, qos=MQTT_QOS)
                    if DEBUG:
                        print(f"Published keystroke {vk_code} to {MQTT_OUTPUT_TOPIC}")
            else:
                if key.vk in range(96, 112):
                    vk_code = str(key.vk)  # Convert vk_code to string
                    client.publish(MQTT_OUTPUT_TOPIC, vk_code, qos=MQTT_QOS)
                    if DEBUG:
                        print(f"Published keystroke {vk_code} to {MQTT_OUTPUT_TOPIC}")
    except Exception as e:
        if DEBUG:
            print(f"Error capturing keystroke: {e}")

# Function to reset ctrl_pressed on release of CTRL key
def on_release(key):
    global ctrl_pressed
    if key == Key.ctrl_l or key == Key.ctrl_r:
        ctrl_pressed = False
        if DEBUG:
            print("CTRL key released")

# Callback function for when the client receives a message from the broker
def on_message(client, userdata, msg):
    message = msg.payload.decode('utf-8')
    if DEBUG:
        print(f"Received message on topic {msg.topic}: {message}")
    
    try:
        if msg.topic == MQTT_INPUT_TOPIC:
            vk_sequence = eval(message)  # Expecting a list like [0x11, 0x12, 0x48]
            if isinstance(vk_sequence, list) and len(vk_sequence) <= 4:
                simulate_keystroke(vk_sequence)
            else:
                if DEBUG:
                    print("Invalid key sequence format or too many keys")
    
    except Exception as e:
        if DEBUG:
            print(f"Error processing message: {e}")

# Callback function for when the client connects to the broker
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT broker")
        # Subscribe to all relevant topics
        client.subscribe([(MQTT_INPUT_TOPIC, MQTT_QOS), (MQTT_OUTPUT_TOPIC, MQTT_QOS)])
        if DEBUG:
            print(f"Subscribed to topics: {MQTT_INPUT_TOPIC}, {MQTT_OUTPUT_TOPIC}")
    else:
        print(f"Failed to connect, return code {rc}")

# Callback function for when the client subscribes to the topic
def on_subscribe(client, userdata, mid, granted_qos):
    if DEBUG:
        print(f"Subscribed with QoS {granted_qos[0]}")

# Set up the MQTT client
client = mqtt.Client()

# Assign the callback functions
client.on_connect = on_connect
client.on_message = on_message
client.on_subscribe = on_subscribe

# Connect to the broker
client.connect(MQTT_BROKER, MQTT_PORT, 60)

# Start the loop to process MQTT messages
client.loop_start()

# Start listener for keystroke capture
listener = Listener(on_press=on_press, on_release=on_release)
listener.start()

print("Listening for MQTT messages and capturing keystrokes...")

# Keep the script running
try:
    while True:
        time.sleep(1)  # Keep the script alive
except KeyboardInterrupt:
    print("Disconnecting from MQTT broker and stopping listener...")
    client.loop_stop()
    client.disconnect()
    listener.stop()
    print("Disconnected.")