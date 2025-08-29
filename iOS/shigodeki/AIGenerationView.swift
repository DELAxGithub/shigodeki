import SwiftUI

struct AIGenerationView: View {
    @ObservedObject var aiGenerator: AITaskGenerator
    let onComplete: (AITaskSuggestion) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    if aiGenerator.isGenerating {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Image(systemName: "brain")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                
                VStack(spacing: 8) {
                    Text("AI タスク生成")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Progress stages (when generating)
            if aiGenerator.isGenerating {
                VStack(spacing: 16) {
                    ProgressStage(
                        title: "AIに接続中",
                        isActive: aiGenerator.progressMessage.contains("Connecting"),
                        isComplete: !aiGenerator.progressMessage.contains("Connecting")
                    )
                    
                    ProgressStage(
                        title: "タスクを生成中",
                        isActive: aiGenerator.progressMessage.contains("Generating"),
                        isComplete: false
                    )
                    
                    ProgressStage(
                        title: "結果を処理中",
                        isActive: aiGenerator.progressMessage.contains("Processing"),
                        isComplete: false
                    )
                }
                .padding()
            }
            
            // Error display
            if let error = aiGenerator.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 8) {
                        Text("生成に失敗しました")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button("再試行") {
                        aiGenerator.error = nil
                        // Retry logic would need to be implemented by the parent
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            
            // Success display
            if let suggestions = aiGenerator.generatedSuggestions, !aiGenerator.isGenerating {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    VStack(spacing: 8) {
                        Text("生成完了！")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(suggestions.tasks.count)個のタスクが生成されました")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("結果を確認") {
                        onComplete(suggestions)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            
            Spacer()
            
            // Cancel button
            if aiGenerator.isGenerating || aiGenerator.error != nil {
                Button("キャンセル") {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var statusText: String {
        if aiGenerator.isGenerating {
            return aiGenerator.progressMessage.isEmpty ? "AIがタスクを生成しています..." : aiGenerator.progressMessage
        } else if aiGenerator.error != nil {
            return "エラーが発生しました"
        } else if aiGenerator.generatedSuggestions != nil {
            return "タスクの生成が完了しました"
        } else {
            return "準備完了"
        }
    }
}

struct ProgressStage: View {
    let title: String
    let isActive: Bool
    let isComplete: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(stageColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(stageColor)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: stageColor))
                } else {
                    Circle()
                        .fill(stageColor.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(isActive ? .medium : .regular)
                .foregroundColor(isActive ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var stageColor: Color {
        if isComplete {
            return .green
        } else if isActive {
            return .blue
        } else {
            return .gray
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(configuration.isPressed ? 0.1 : 0.0))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    AIGenerationView(
        aiGenerator: {
            let generator = AITaskGenerator()
            generator.isGenerating = true
            generator.progressMessage = "タスクを生成中..."
            return generator
        }(),
        onComplete: { _ in },
        onCancel: { }
    )
}