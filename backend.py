import os
from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor

app = Flask(__name__)
CORS(app)

# Function to load and process data
def load_and_process_data(file_name):
    try:
        # Check if file exists
        if not os.path.exists(file_name):
            raise FileNotFoundError(f"File not found: {file_name}")

        print(f"Loading data from: {file_name}")  # Print the path
        data = pd.read_csv(file_name, sep=';')
        data = data.drop(columns='name')
        data = data.rename(columns={'open': 'monthly_open', 'high': 'monthly_high', 'low': 'monthly_low', 'close': 'monthly_close'})
        data = data.iloc[81:]
        data = data.dropna()
        data['timestamp'] = data['timestamp'].str.replace("T00:00:00.000Z", "", regex=False)
        data['timestamp'] = pd.to_datetime(data['timestamp'], format='%Y-%m-%d', errors='coerce')
        data = data.reset_index(drop=True)
        return data
    except Exception as e:
        raise Exception(f"Error processing file: {e}")

# File paths (Update the path as per your system)
file_names = {
    'bitcoin': 'C:/Users/TECHNOSELLERS/Desktop/cryptovision_ai/lib/services/BTC_All_graph_coinmarketcap.csv',
    'ethereum': 'C:/Users/TECHNOSELLERS/Desktop/cryptovision_ai/lib/services/ETH_All_graph_coinmarketcap.csv'
}

# Train the model for both coins at the beginning
models = {}

def train_model(coin):
    file_to_process = file_names[coin]
    data = load_and_process_data(file_to_process)
    X = data[['monthly_open', 'monthly_high', 'monthly_low', 'volume', 'marketCap']]
    y = data['monthly_close']
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    rf_model = RandomForestRegressor(n_estimators=200, random_state=42)
    rf_model.fit(X_train, y_train)
    return rf_model

# Train models for both Bitcoin and Ethereum
models['bitcoin'] = train_model('bitcoin')
models['ethereum'] = train_model('ethereum')

# API route to predict closing price
@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Get input data from the request
        data_input = request.json
        monthly_open = float(data_input['open'])
        monthly_high = float(data_input['high'])
        monthly_low = float(data_input['low'])
        volume = float(data_input['volume'])
        marketCap = float(data_input['marketCap'])
        selected_coin = data_input['coin']  # Get the selected coin from the request

        if selected_coin not in models:
            return jsonify({'error': 'Invalid coin selected'}), 400

        # Create a DataFrame for manual input data
        manual_input_df = pd.DataFrame([[monthly_open, monthly_high, monthly_low, volume, marketCap]],
                                       columns=['monthly_open', 'monthly_high', 'monthly_low', 'volume', 'marketCap'])

        # Predict the closing price
        predicted_price = models[selected_coin].predict(manual_input_df)[0]

        return jsonify({'predicted_closing_price': round(predicted_price, 2)}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 400

# Main execution point
if __name__ == '__main__':
    app.run(debug=True)
