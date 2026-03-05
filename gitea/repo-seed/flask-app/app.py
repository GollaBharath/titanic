from flask import Flask, render_template, request, jsonify, send_file
import os
import json
import uuid
from datetime import datetime

app = Flask(__name__)

# Directory to store tickets
TICKETS_DIR = '/opt/app/tickets'
os.makedirs(TICKETS_DIR, exist_ok=True)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/book', methods=['POST'])
def book_ticket():
    try:
        data = request.get_json()
        
        # Extract booking information
        name = data.get('name', '')
        email = data.get('email', '')
        phone = data.get('phone', '')
        date = data.get('date', '1912-04-15')
        cabin = data.get('cabin', 'Standard')
        
        # Create ticket data
        ticket_data = {
            "name": name,
            "email": email,
            "phone": phone,
            "date": date,
            "cabin": cabin
        }
        
        # Generate unique ticket ID
        ticket_id = f"ticket_{uuid.uuid4().hex[:16]}.json"
        ticket_path = os.path.join(TICKETS_DIR, ticket_id)
        
        # Save ticket to file
        with open(ticket_path, 'w') as f:
            json.dump(ticket_data, f, indent=2)
        
        return jsonify({
            "status": "success",
            "message": "Ticket booked successfully!",
            "ticket_id": ticket_id
        }), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/download', methods=['GET'])
def download_ticket():
    """
    VULNERABLE TO DIRECTORY TRAVERSAL
    No sanitization of the ticket parameter allows reading arbitrary files
    """
    ticket = request.args.get('ticket')
    
    if not ticket:
        return jsonify({"error": "Ticket parameter is required"}), 400
    
    # VULNERABILITY: No path sanitization - allows directory traversal
    json_filepath = os.path.join(TICKETS_DIR, ticket)
    
    if os.path.exists(json_filepath):
        return send_file(json_filepath, as_attachment=True, download_name=ticket)
    else:
        return jsonify({"error": "Ticket not found"}), 404

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
