from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({
        "message": "Hello from Flask!",
        "version": os.getenv('APP_VERSION', '1.0.0'),
        "environment": os.getenv('ENVIRONMENT', 'development')
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)


    ## Oj3StDRDEcGTRTAdR1YHFC