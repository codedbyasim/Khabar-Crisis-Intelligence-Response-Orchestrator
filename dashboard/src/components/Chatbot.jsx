import React, { useState, useEffect, useRef } from 'react';
import { Bot, MessageSquare, Send, X, CheckCircle2, AlertTriangle, ShieldAlert } from 'lucide-react';

export default function Chatbot({ apiBase, onActionExecuted }) {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState([
    {
      id: 1,
      role: 'assistant',
      content: 'Welcome coordinator. I am the KHABAR CIRO Assistant. Ask me to "Summarize active crises", "Dispatch Rescue 1122 with 2 units to [incident_id]", "Register new resource", or "Clear database".'
    }
  ]);
  const [inputValue, setInputValue] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef(null);

  const SUGGESTIONS = [
    'Summarize active crises',
    'List all resources',
    'Clear all incidents'
  ];

  // Auto scroll to bottom
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    if (isOpen) {
      scrollToBottom();
    }
  }, [messages, isOpen]);

  const handleSendMessage = async (text) => {
    if (!text || !text.trim() || isLoading) return;

    const userText = text.trim();
    const newUserMsg = {
      id: Date.now(),
      role: 'user',
      content: userText
    };

    setMessages(prev => [...prev, newUserMsg]);
    setInputValue('');
    setIsLoading(true);

    // Prepare history for API
    const history = messages
      .filter(msg => msg.role !== 'system')
      .map(msg => ({
        role: msg.role,
        content: msg.content
      }));

    try {
      const response = await fetch(`${apiBase}/admin/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: userText,
          history: history,
          language: 'English'
        })
      });

      const data = await response.json();

      if (data.success) {
        const assistantMsg = {
          id: Date.now() + 1,
          role: 'assistant',
          content: data.response || 'Action processed.',
          command: data.command_executed
        };
        setMessages(prev => [...prev, assistantMsg]);

        // If a command was successfully executed, trigger parent refresh
        if (data.command_executed && data.command_executed.success) {
          if (onActionExecuted) {
            onActionExecuted();
          }
        }
      } else {
        setMessages(prev => [...prev, {
          id: Date.now() + 1,
          role: 'assistant',
          content: 'Sorry, I encountered an issue: ' + (data.error || 'Unknown error')
        }]);
      }
    } catch (err) {
      console.error('Chat error:', err);
      setMessages(prev => [...prev, {
        id: Date.now() + 1,
        role: 'assistant',
        content: 'Error: Could not establish connection to the admin chat server.'
      }]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <>
      {/* Floating Toggle Button */}
      <div className="chatbot-toggle" onClick={() => setIsOpen(!isOpen)}>
        {isOpen ? <X size={24} /> : <MessageSquare size={24} />}
      </div>

      {/* Expanded Chat Widget */}
      {isOpen && (
        <div className="chatbot-container">
          {/* Header */}
          <div className="chatbot-header">
            <div className="chatbot-title">
              <div className="sidebar-logo-icon" style={{ width: 28, height: 28, fontSize: 13, boxShadow: 'none' }}>🤖</div>
              <div>
                <div style={{ fontWeight: 700, fontSize: 13, lineHeight: 1.2 }}>KHABAR AI Assistant</div>
                <div style={{ fontSize: 9, opacity: 0.6, letterSpacing: 0.5 }}>COMMAND CONSOLE</div>
              </div>
            </div>
            <button className="chatbot-close-btn" onClick={() => setIsOpen(false)}>
              <X size={16} />
            </button>
          </div>

          {/* Messages */}
          <div className="chatbot-messages">
            {messages.map(msg => (
              <div key={msg.id} style={{ display: 'flex', flexDirection: 'column', width: '100%' }}>
                <div className={`chatbot-message ${msg.role === 'user' ? 'chatbot-msg-user' : 'chatbot-msg-assistant'}`}>
                  {msg.content}

                  {/* Render Command Result if present */}
                  {msg.command && (
                    <div className={`chatbot-command-indicator ${msg.command.success ? 'success-cmd' : 'error-cmd'}`}>
                      {msg.command.success ? (
                        <>
                          <CheckCircle2 size={13} />
                          <span>Command Executed: {msg.command.detail}</span>
                        </>
                      ) : (
                        <>
                          <ShieldAlert size={13} />
                          <span>Command Failed: {msg.command.detail}</span>
                        </>
                      )}
                    </div>
                  )}
                </div>
              </div>
            ))}
            {isLoading && (
              <div className="chatbot-typing">
                <div className="chatbot-dot"></div>
                <div className="chatbot-dot"></div>
                <div className="chatbot-dot"></div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          {/* Suggestions */}
          <div className="chatbot-suggestions">
            {SUGGESTIONS.map((sug, i) => (
              <button
                key={i}
                className="chatbot-suggest-btn"
                onClick={() => handleSendMessage(sug)}
                disabled={isLoading}
              >
                {sug}
              </button>
            ))}
          </div>

          {/* Input Box */}
          <div className="chatbot-input-container">
            <input
              type="text"
              className="chatbot-input"
              placeholder="Ask or command (e.g. 'Dispatch NDMA to SIG-178...')"
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') handleSendMessage(inputValue);
              }}
              disabled={isLoading}
            />
            <button
              className="chatbot-send-btn"
              onClick={() => handleSendMessage(inputValue)}
              disabled={!inputValue.trim() || isLoading}
            >
              <Send size={16} />
            </button>
          </div>
        </div>
      )}
    </>
  );
}
