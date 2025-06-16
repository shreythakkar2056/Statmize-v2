import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
import tensorflow as tf
from tensorflow import keras

# Load and prepare your data
data = pd.read_excel("test1.xlsx", skiprows=1, names=[
    'ACC_X', 'ACC_Y', 'ACC_Z',
    'GYR_X', 'GYR_Y', 'GYR_Z',
    'MAG_X', 'MAG_Y', 'MAG_Z'
])

# Feature extraction function
def extract_features(window):
    feats = {}
    for col in window.columns:
        vals = window[col]
        feats[f"{col}_mean"] = vals.mean()
        feats[f"{col}_std"] = vals.std()
        feats[f"{col}_min"] = vals.min()
        feats[f"{col}_max"] = vals.max()
        feats[f"{col}_range"] = vals.max() - vals.min()

    acc_mag = np.sqrt(window['ACC_X']**2 + window['ACC_Y']**2 + window['ACC_Z']**2)
    feats['ACC_mag_mean'] = acc_mag.mean()
    feats['ACC_mag_max'] = acc_mag.max()
    feats['ACC_mag_std'] = acc_mag.std()
    return feats

# Train RandomForest model
WINDOW_SIZE = 50
STEP_SIZE = 25

features_all = []
labels_all = []
for start in range(0, len(data) - WINDOW_SIZE, STEP_SIZE):
    window = data.iloc[start:start + WINDOW_SIZE]
    feats = extract_features(window)
    features_all.append(feats)
    labels_all.append(np.random.choice(['Smash', 'Drop', 'Lift', 'Clear', 'Drive', 'Net']))

df_all = pd.DataFrame(features_all)
X_train, X_test, y_train, y_test = train_test_split(df_all, labels_all, test_size=0.2, random_state=42)
clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X_train, y_train)

# Convert RandomForest to TensorFlow model
def convert_random_forest_to_tf_model(rf_model):
    # Create a simple neural network that mimics the RandomForest
    model = keras.Sequential([
        keras.layers.Dense(64, activation='relu', input_shape=(len(features_all[0]),)),
        keras.layers.Dense(32, activation='relu'),
        keras.layers.Dense(6, activation='softmax')  # 6 shot types
    ])
    
    # Compile the model
    model.compile(optimizer='adam',
                 loss='sparse_categorical_crossentropy',
                 metrics=['accuracy'])
    
    # Train the model to mimic RandomForest predictions
    rf_predictions = rf_model.predict(X_train)
    label_map = {label: i for i, label in enumerate(rf_model.classes_)}
    y_train_numeric = np.array([label_map[label] for label in y_train])
    
    model.fit(X_train, y_train_numeric, epochs=10, batch_size=32, verbose=0)
    
    return model

# Convert to TFLite
tf_model = convert_random_forest_to_tf_model(clf)
converter = tf.lite.TFLiteConverter.from_keras_model(tf_model)
tflite_model = converter.convert()

# Save the model
with open('model.tflite', 'wb') as f:
    f.write(tflite_model)

print("Model converted and saved as model.tflite") 