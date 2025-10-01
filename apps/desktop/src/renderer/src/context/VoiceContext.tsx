import React, { createContext, ReactNode, useContext, useState } from 'react';

interface VoiceContextType {
  isListening: boolean;
  isRecording: boolean;
  transcript: string;
  startListening: () => void;
  stopListening: () => void;
  startRecording: () => void;
  stopRecording: () => void;
}

const VoiceContext = createContext<VoiceContextType | undefined>(undefined);

interface VoiceProviderProps {
  children: ReactNode;
}

export const VoiceProvider: React.FC<VoiceProviderProps> = ({ children }) => {
  const [isListening, setIsListening] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [transcript, setTranscript] = useState('');

  const startListening = () => {
    setIsListening(true);
    setTranscript(''); // Clear transcript when starting to listen
    // TODO: Implement voice listening logic
  };

  const stopListening = () => {
    setIsListening(false);
    // TODO: Implement stop listening logic
  };

  const startRecording = () => {
    setIsRecording(true);
    // TODO: Implement voice recording logic
  };

  const stopRecording = () => {
    setIsRecording(false);
    // TODO: Implement stop recording logic
  };

  const value: VoiceContextType = {
    isListening,
    isRecording,
    transcript,
    startListening,
    stopListening,
    startRecording,
    stopRecording,
  };

  return (
    <VoiceContext.Provider value={value}>
      {children}
    </VoiceContext.Provider>
  );
};

export const useVoice = (): VoiceContextType => {
  const context = useContext(VoiceContext);
  if (context === undefined) {
    throw new Error('useVoice must be used within a VoiceProvider');
  }
  return context;
};