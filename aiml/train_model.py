import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
import joblib
import json
import argparse
import sys

# -------- STEP 1: Load sensor data -------- #
data = pd.read_excel("test1.xlsx", skiprows=1, names=[
    'ACC_X', 'ACC_Y', 'ACC_Z',
    'GYR_X', 'GYR_Y', 'GYR_Z',
    'MAG_X', 'MAG_Y', 'MAG_Z'
])

# -------- STEP 2: Sliding Window Feature Extraction -------- #
WINDOW_SIZE = 50
STEP_SIZE = 25

def extract_features(window):
    feats = {}
    for col in window.columns:
        vals = window[col]
        feats[f"{col}_mean"] = vals.mean()
        feats[f"{col}_std"] = vals.std()
        feats[f"{col}_min"] = vals.min()
        feats[f"{col}_max"] = vals.max()
        feats[f"{col}_range"] = vals.max() - vals.min()

    # Magnitudes
    acc_mag = np.sqrt(window['ACC_X']**2 + window['ACC_Y']**2 + window['ACC_Z']**2)
    feats['ACC_mag_mean'] = acc_mag.mean()
    feats['ACC_mag_max'] = acc_mag.max()
    feats['ACC_mag_std'] = acc_mag.std()
    return feats, acc_mag.mean()

def suggest_variation(shot):
    suggestions = {
        'Smash': ['Try steeper angle', 'Mix with Drop'],
        'Drop': ['Fast Drop as variation', 'Follow up with Net shot'],
        'Lift': ['Deep lifts to corners', 'Try more cross-court'],
        'Clear': ['Use to reset rally', 'Try attacking clear'],
        'Drive': ['Use in fast rallies', 'Work on flat drive timing'],
        'Net': ['Add tumble', 'Try net kill after it']
    }
    return suggestions.get(shot, ['Keep it up!'])

def analyze_shot(data):
    # Convert single data point to DataFrame
    df = pd.DataFrame([data])
    
    # Extract features
    feats, intensity = extract_features(df)
    
    # Load model (you should save this after training)
    try:
        clf = joblib.load('aiml/tennis_model.joblib')
    except:
        # If model doesn't exist, use random prediction for testing
        shot_types = ['Smash', 'Drop', 'Lift', 'Clear', 'Drive', 'Net']
        predicted_shot = np.random.choice(shot_types)
    else:
        # Predict shot type
        input_df = pd.DataFrame([feats])
        predicted_shot = clf.predict(input_df)[0]
    
    # Get suggestions
    suggestions = suggest_variation(predicted_shot)
    
    # Return results
    return {
        'Shot': predicted_shot,
        'Intensity': float(intensity),
        'Suggestions': suggestions
    }

def main():
    parser = argparse.ArgumentParser(description='Analyze tennis shot data')
    parser.add_argument('--input', required=True, help='Input JSON file path')
    parser.add_argument('--output', required=True, help='Output JSON file path')
    args = parser.parse_args()

    try:
        # Read input data
        with open(args.input, 'r') as f:
            data = json.load(f)
        
        # Analyze shot
        result = analyze_shot(data)
        
        # Write output
        with open(args.output, 'w') as f:
            json.dump(result, f)
            
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
