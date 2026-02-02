//
//  AppFont.swift
//  GagaeSsi
//
//  Created by 조영현 on 7/25/25.
//

import UIKit

enum AppFont {
    enum Pretendard {
        static func thin(size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Thin", size: size) ?? .systemFont(ofSize: size)
        }
        
        static func extraLight(size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-ExtraLight", size: size) ?? .systemFont(ofSize: size)
        }
        
        static func light(size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Light", size: size) ?? .systemFont(ofSize: size)
        }
        
        static func regular(size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Regular", size: size) ?? .systemFont(ofSize: size)
        }
        
        static func medium(size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Medium", size: size) ?? .systemFont(ofSize: size)
        }
        
        static func semiBold(size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-SemiBold", size: size) ?? .systemFont(ofSize: size)
        }

        static func bold(size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Bold", size: size) ?? .boldSystemFont(ofSize: size)
        }
        
        static func extraBold(size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-ExtraBold", size: size) ?? .boldSystemFont(ofSize: size)
        }
        
        static func black(size: CGFloat) -> UIFont {
            UIFont(name: "Pretendard-Black", size: size) ?? .systemFont(ofSize: size)
        }
    }
}
