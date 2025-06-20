//
//  UILabel+.swift
//  DontBe-iOS
//
//  Created by 변희주 on 1/8/24.
//

import UIKit

extension UILabel {
    func setTextWithLineHeight(text: String?, lineHeight: CGFloat, alignment: NSTextAlignment){
        if let text = text {
            let style = NSMutableParagraphStyle()
            style.maximumLineHeight = lineHeight
            style.minimumLineHeight = lineHeight
            
            let attributes: [NSAttributedString.Key: Any] = [
                .paragraphStyle: style,
            ]
            
            let attrString = NSAttributedString(string: text,
                                                attributes: attributes)
            self.attributedText = attrString
            self.textAlignment = alignment
        }
    }
    
    /// 특정 텍스트만 폰트를 다르게 주는 함수
    func asFont(targetString: String, font: UIFont) {
        let fullText = text ?? ""
        let attributedString = NSMutableAttributedString(string: fullText)
        let range = (fullText as NSString).range(of: targetString)
        attributedString.addAttribute(.font, value: font, range: range)
        attributedText = attributedString
    }
    
    func setTextWithLineHeightAndFont(text: String?, targetString: String, font: UIFont) {
        if let text = text {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.font(.body4)
            ]
            
            let attrString = NSMutableAttributedString(string: text, attributes: attributes)
            
            // 특정 문자열에 대해서만 폰트 변경
            let range = (text as NSString).range(of: targetString)
            attrString.addAttribute(.font, value: font, range: range)
            attrString.addAttribute(.foregroundColor, value: UIColor.clear, range: range)
            
            self.attributedText = attrString
        }
    }
    
    class func lineNumber(label: UILabel, labelWidth: CGFloat) -> Int {
        let boundingRect = label.text?.boundingRect(with: .zero, options: [.usesFontLeading], attributes: [.font: label.font as Any], context: nil)
        return Int((boundingRect?.width ?? 0) / labelWidth + 1)
    }
}
