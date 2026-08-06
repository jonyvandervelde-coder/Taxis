//
//  AppLockView.swift
//  TaxÍs
//
//  Full-screen lock screen. Shown automatically when the app moves to
//  the foreground while AppLockService.isLocked == true. Supports both
//  biometric (Face ID / Touch ID) and a 4-digit PIN pad.
//

import SwiftUI

struct AppLockView: View {
    @ObservedObject var lockService: AppLockService

    @State private var pinInput    = ""
    @State private var pinError    = false
    @State private var showingPIN  = false   // fallback when biometric fails

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()

            VStack(spacing: 36) {
                TaxIsLogo()
                    .frame(height: 32)
                    .padding(.bottom, 8)

                Text("Staðfestu auðkenningu")
                    .font(.title3.bold())
                    .foregroundStyle(TaxIsTheme.text)

                if lockService.lockMethod == "biometric" && !showingPIN {
                    biometricPrompt
                } else {
                    pinPad
                }
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            if lockService.lockMethod == "biometric" {
                Task { await lockService.unlockWithBiometric() }
            }
        }
    }

    // MARK: - Biometric prompt

    private var biometricPrompt: some View {
        VStack(spacing: 20) {
            Button {
                Task {
                    let ok = await lockService.unlockWithBiometric()
                    if !ok { showingPIN = true }
                }
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: lockService.biometricIcon)
                        .font(.system(size: 56))
                        .foregroundStyle(TaxIsTheme.mint)
                    Text(lockService.biometricLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TaxIsTheme.text)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(TaxIsTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                        .strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1)
                )
            }

            Button("Nota PIN í staðinn") {
                showingPIN = true
            }
            .font(.footnote)
            .foregroundStyle(TaxIsTheme.muted)
        }
    }

    // MARK: - PIN pad

    private var pinPad: some View {
        VStack(spacing: 24) {
            // Dot display
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < pinInput.count ? TaxIsTheme.mint : TaxIsTheme.borderStrong)
                        .frame(width: 14, height: 14)
                        .animation(.easeInOut(duration: 0.15), value: pinInput.count)
                }
            }
            .padding(.bottom, 4)

            if pinError {
                Text("Rangt PIN. Reyndu aftur.")
                    .font(.footnote)
                    .foregroundStyle(TaxIsTheme.redText)
                    .transition(.opacity)
            }

            // 3-column number grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(["1","2","3","4","5","6","7","8","9","","0","⌫"], id: \.self) { key in
                    if key.isEmpty {
                        Color.clear.frame(height: 64)
                    } else {
                        Button {
                            handleKey(key)
                        } label: {
                            Text(key)
                                .font(.title2.weight(.medium))
                                .foregroundStyle(TaxIsTheme.text)
                                .frame(height: 64)
                                .frame(maxWidth: .infinity)
                                .background(TaxIsTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                                .overlay(
                                    RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                                        .strokeBorder(TaxIsTheme.border, lineWidth: 1)
                                )
                        }
                    }
                }
            }

            if lockService.lockMethod == "biometric" {
                Button {
                    showingPIN = false
                    Task { await lockService.unlockWithBiometric() }
                } label: {
                    Label(lockService.biometricLabel, systemImage: lockService.biometricIcon)
                        .font(.footnote)
                        .foregroundStyle(TaxIsTheme.mintText)
                }
            }
        }
    }

    // MARK: - PIN input

    private func handleKey(_ key: String) {
        if key == "⌫" {
            if !pinInput.isEmpty { pinInput.removeLast() }
            pinError = false
        } else if pinInput.count < 4 {
            pinInput += key
            if pinInput.count == 4 {
                let ok = lockService.unlock(withPIN: pinInput)
                if !ok {
                    withAnimation { pinError = true }
                    pinInput = ""
                }
            }
        }
    }
}
