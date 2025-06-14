//
//  WriteReplyEditorView.swift
//  DontBe-iOS
//
//  Created by yeonsu on 1/14/24.
//

import UIKit

import SnapKit

final class WriteReplyEditorView: UIView {

    // MARK: - UI Components
    
    private let backgroundUIView: UIView = {
        let view = UIView()
        view.backgroundColor = .donWhite
        view.layer.cornerRadius = 8.adjusted
        return view
    }()
    
    let userProfileImage: UIImageView = {
        let imageView = UIImageView()
        imageView.load(url: loadUserData()?.userProfileImage ?? StringLiterals.Network.baseImageURL)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = imageView.frame.size.width / 2.adjusted
        imageView.clipsToBounds = true
        return imageView
    }()
    
    var userNickname: UILabel = {
        let label = UILabel()
        label.text = "\(loadUserData()?.userNickname ?? "")"
        label.font = UIFont.font(.body3)
        label.textColor = .donBlack
        return label
    }()
    
    let contentTextView: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.font(.body4)
        textView.textColor = .donBlack
        textView.tintColor = .donLink
        textView.backgroundColor = .clear
        textView.addPlaceholder(StringLiterals.Write.writeContentPlaceholder, padding: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.showsVerticalScrollIndicator = false
        return textView
    }()
    
    // MARK: - Life Cycles
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setUI()
        setHierarchy()
        setLayout()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Extensions

extension WriteReplyEditorView {
    func setUI() {
        self.backgroundColor = .donGray1
    }
    
    private func setHierarchy() {
        self.addSubviews(backgroundUIView)
        
        backgroundUIView.addSubviews(userProfileImage,
                                     userNickname,
                                     contentTextView)
    }
    
    private func setLayout() {
        backgroundUIView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16.adjusted)
            $0.top.equalTo(8.adjusted)
            $0.bottom.equalToSuperview()
        }
        
        userProfileImage.snp.makeConstraints {
            $0.top.equalToSuperview().offset(18.adjusted)
            $0.leading.equalToSuperview().offset(10.adjusted)
            $0.width.equalTo(44.adjusted)
            $0.height.equalTo(44.adjusted)
        }
        
        userNickname.snp.makeConstraints {
            $0.top.equalTo(userProfileImage.snp.top).offset(1.adjusted)
            $0.leading.equalTo(userProfileImage.snp.trailing).offset(11.adjusted)
        }
        
        contentTextView.snp.makeConstraints {
            $0.top.equalTo(userNickname.snp.bottom).offset(4.adjusted)
            $0.leading.equalTo(userNickname.snp.leading)
            $0.trailing.equalToSuperview().inset(16.adjusted)
            $0.bottom.equalToSuperview()
        }
    }
}
