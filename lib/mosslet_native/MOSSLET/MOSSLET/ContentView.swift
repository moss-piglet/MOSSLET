//
//  ContentView.swift
//  MOSSLET
//
//  Created by mark on 8/21/25.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct ContentView: View {
    var body: some View {
        WebView(url: URL(string: "https://mosslet.com")!)
            .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    ContentView()
}
