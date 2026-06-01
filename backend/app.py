# ============================================================
# app.py - Flask Backend for PULMA AI
# Respiratory Disease Detection
# ============================================================

import os
import base64
import numpy as np

from flask      import Flask, request, jsonify
from flask_cors import CORS
from tensorflow import keras
import tensorflow as tf
from PIL        import Image
import cv2

app = Flask(__name__)
CORS(app)  # Required for Flutter Android emulator (10.0.2.2)

UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png', 'bmp'}
IMG_SIZE = (224, 224)

# ============================================================
# CLASS ORDER — MUST match the order Keras assigned during training.
# Keras flow_from_directory / image_dataset_from_directory sort folder
# names with Python's case-SENSITIVE sorted(): uppercase (A-Z, 65-90)
# come before lowercase (a-z, 97-122). So 'covid' (lowercase) sorts LAST.
#   sorted(['Bengin cases','Malignant cases','Normal cases',
#           'Pneumonia','Tuberclosis','covid'])
#   -> ['Bengin cases','Malignant cases','Normal cases',
#       'Pneumonia','Tuberclosis','covid']
# This matches the order emitted by the original training Colab notebook.
# ============================================================
CLASS_NAMES = [
    'Bengin cases',      # index 0
    'Malignant cases',   # index 1
    'Normal cases',      # index 2
    'Pneumonia',         # index 3
    'Tuberclosis',       # index 4
    'covid',             # index 5
]

CLASS_DISPLAY_NAMES = {
    'Bengin cases'   : 'Benign Cancer',
    'covid'          : 'COVID-19',
    'Malignant cases': 'Malignant Cancer',
    'Normal cases'   : 'Normal',
    'Pneumonia'      : 'Pneumonia',
    'Tuberclosis'    : 'Tuberculosis',
}

# ============================================================
# Load Model — file is densenet121_best.h5
# ============================================================
MODEL_PATH = os.path.join(
    os.path.dirname(__file__),
    '..',
    'model',
    'densenet121_best.h5'   # exact filename in the model/ folder
)

print("Loading model from:", MODEL_PATH)
try:
    model = keras.models.load_model(MODEL_PATH)
    print("Model loaded OK. Input:", model.input_shape, "Output:", model.output_shape)
except Exception as e:
    print("ERROR loading model:", e)
    model = None

# ============================================================
# Helpers
# ============================================================

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def preprocess_image(image_path):
    """Open → RGB → 224x224 → numpy → normalize → add batch dim."""
    img = Image.open(image_path).convert('RGB').resize(IMG_SIZE)
    arr = np.array(img, dtype=np.float32) / 255.0
    return np.expand_dims(arr, axis=0)  # (1, 224, 224, 3)


def generate_gradcam(img_array, pred_index):
    """
    Grad-CAM for DenseNet121 wrapped in Sequential.
    The DenseNet121 base is at index 0 of the Sequential model.
    We reach inside it to find the last Conv2D layer.
    Returns base64-encoded PNG string: 'data:image/png;base64,...'
    """
    # The Sequential model contains DenseNet121 as its first layer
    # We need to find the last Conv2D inside the DenseNet base
    densenet_base = None
    for layer in model.layers:
        if hasattr(layer, 'layers'):  # it's a nested model
            densenet_base = layer
            break

    last_conv_name = None
    if densenet_base is not None:
        for layer in reversed(densenet_base.layers):
            if isinstance(layer, tf.keras.layers.Conv2D):
                last_conv_name = layer.name
                break

    # Fallback: scan the full model
    if last_conv_name is None:
        for layer in reversed(model.layers):
            if isinstance(layer, tf.keras.layers.Conv2D):
                last_conv_name = layer.name
                break

    # Known DenseNet121 last conv layer name as ultimate fallback
    if last_conv_name is None:
        last_conv_name = 'conv5_block16_2_conv'

    # Build grad model: inputs → [conv_output, predictions]
    if densenet_base is not None:
        inner_model = tf.keras.Model(
            inputs=densenet_base.input,
            outputs=[densenet_base.get_layer(last_conv_name).output,
                     densenet_base.output]
        )
        with tf.GradientTape() as tape:
            conv_out, base_out = inner_model(img_array)
            # Pass base_out through remaining layers of Sequential
            x = base_out
            found_base = False
            for layer in model.layers:
                if not found_base:
                    if hasattr(layer, 'layers'):
                        found_base = True
                    continue
                x = layer(x)
            class_score = x[:, pred_index]
        grads = tape.gradient(class_score, conv_out)
    else:
        grad_model = tf.keras.Model(
            inputs=model.inputs,
            outputs=[model.get_layer(last_conv_name).output, model.output]
        )
        with tf.GradientTape() as tape:
            conv_out, predictions = grad_model(img_array)
            class_score = predictions[:, pred_index]
        grads = tape.gradient(class_score, conv_out)

    # Pool gradients and weight feature maps
    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))
    conv_out     = conv_out[0].numpy()
    pooled_grads = pooled_grads.numpy()
    for i in range(pooled_grads.shape[-1]):
        conv_out[:, :, i] *= pooled_grads[i]

    heatmap = np.mean(conv_out, axis=-1)
    heatmap = np.maximum(heatmap, 0)
    if heatmap.max() != 0:
        heatmap /= heatmap.max()

    # Resize and colorize
    heatmap_resized = cv2.resize(heatmap, IMG_SIZE)
    heatmap_uint8   = np.uint8(255 * heatmap_resized)
    heatmap_color   = cv2.applyColorMap(heatmap_uint8, cv2.COLORMAP_JET)

    # Overlay on original image
    original_rgb = np.uint8(img_array[0] * 255)
    original_bgr = cv2.cvtColor(original_rgb, cv2.COLOR_RGB2BGR)
    superimposed  = cv2.addWeighted(original_bgr, 0.6, heatmap_color, 0.4, 0)

    _, buffer  = cv2.imencode('.png', superimposed)
    b64        = base64.b64encode(buffer).decode('utf-8')
    return f"data:image/png;base64,{b64}"


# ============================================================
# Routes
# ============================================================

@app.route('/', methods=['GET'])
def home():
    return jsonify({
        'project': 'PULMA AI',
        'status' : 'running',
        'classes': list(CLASS_DISPLAY_NAMES.values())
    })


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status'      : 'running',
        'model_loaded': model is not None,
        'classes'     : CLASS_NAMES,
        'input_size'  : '224x224'
    })


@app.route('/predict', methods=['POST'])
def predict():
    if model is None:
        return jsonify({'status': 'error', 'message': 'Model not loaded.'}), 500
    if 'file' not in request.files:
        return jsonify({'status': 'error', 'message': 'No file. Use key: file'}), 400

    file = request.files['file']
    if file.filename == '' or not allowed_file(file.filename):
        return jsonify({'status': 'error', 'message': 'Invalid or missing file.'}), 400

    saved_path = os.path.join(UPLOAD_FOLDER, 'predict_' + file.filename)
    file.save(saved_path)

    try:
        img_array   = preprocess_image(saved_path)
        preds       = model.predict(img_array, verbose=0)
        pred_index  = int(np.argmax(preds[0]))
        confidence  = float(preds[0][pred_index]) * 100
        pred_class  = CLASS_NAMES[pred_index]
        disease     = CLASS_DISPLAY_NAMES[pred_class]

        all_probs = {
            CLASS_DISPLAY_NAMES[CLASS_NAMES[i]]: round(float(preds[0][i]) * 100, 2)
            for i in range(len(CLASS_NAMES))
        }
        return jsonify({
            'status'           : 'success',
            'predicted_class'  : pred_class,
            'disease'          : disease,
            'confidence'       : round(confidence, 2),
            'all_probabilities': all_probs
        })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500
    finally:
        try:
            os.remove(saved_path)
        except Exception:
            pass


@app.route('/gradcam', methods=['POST'])
def gradcam():
    if model is None:
        return jsonify({'status': 'error', 'message': 'Model not loaded.'}), 500
    if 'file' not in request.files:
        return jsonify({'status': 'error', 'message': 'No file. Use key: file'}), 400

    file = request.files['file']
    if file.filename == '' or not allowed_file(file.filename):
        return jsonify({'status': 'error', 'message': 'Invalid file.'}), 400

    saved_path = os.path.join(UPLOAD_FOLDER, 'gradcam_' + file.filename)
    file.save(saved_path)

    try:
        img_array  = preprocess_image(saved_path)
        preds      = model.predict(img_array, verbose=0)
        pred_index = int(np.argmax(preds[0]))
        confidence = float(preds[0][pred_index]) * 100
        disease    = CLASS_DISPLAY_NAMES[CLASS_NAMES[pred_index]]
        gradcam_b64 = generate_gradcam(img_array, pred_index)

        return jsonify({
            'status'       : 'success',
            'gradcam_image': gradcam_b64,
            'disease'      : disease,
            'confidence'   : round(confidence, 2)
        })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500
    finally:
        try:
            os.remove(saved_path)
        except Exception:
            pass


# ============================================================
# Run
# ============================================================
if __name__ == '__main__':
    print("\n" + "="*50)
    print("  PULMA AI Backend - http://0.0.0.0:5000")
    print("  Android emulator -> http://10.0.2.2:5000")
    print("="*50 + "\n")
    app.run(host='0.0.0.0', port=5000, debug=True)
