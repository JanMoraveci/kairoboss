//
//  PostDetailViewModel.swift
//  DontBe-iOS
//
//  Created by yeonsu on 1/17/24.
//

import Foundation
import Combine

import Amplitude

final class PostDetailViewModel: ViewModelType {
    
    private let cancelBag = CancelBag()
    private let networkProvider: NetworkServiceType
    private var getPostData = PassthroughSubject<PostDetailResponseDTO, Never>()
    private let toggleLikeButton = PassthroughSubject<Bool, Never>()
    var isLikeButtonClicked: Bool = false
    private var getPostReplyData = PassthroughSubject<[PostReplyResponseDTO], Never>()
    private let clickedRadioButtonState = PassthroughSubject<Int, Never>()
    
    private let toggleCommentLikeButton = PassthroughSubject<Bool, Never>()
    var isCommentLikeButtonClicked: Bool = false
    var cursor: Int = -1
    
    var postDetailData: [String] = []
    var postReplyData: [PostReplyResponseDTO] = []
    var postReplyDatas: [PostReplyResponseDTO] = []
    
    private var isFirstReasonChecked = false
    private var isSecondReasonChecked = false
    private var isThirdReasonChecked = false
    private var isFourthReasonChecked = false
    private var isFifthReasonChecked = false
    private var isSixthReasonChecked = false
    
    struct Input {
        let viewUpdate: AnyPublisher<Int, Never>?
        let likeButtonTapped: AnyPublisher<(Bool, Int), Never>?
        let collectionViewUpdata: AnyPublisher<Int, Never>?
        let commentLikeButtonTapped: AnyPublisher<(Bool, Int, String), Never>?
        let firstReasonButtonTapped: AnyPublisher<Void, Never>?
        let secondReasonButtonTapped: AnyPublisher<Void, Never>?
        let thirdReasonButtonTapped: AnyPublisher<Void, Never>?
        let fourthReasonButtonTapped: AnyPublisher<Void, Never>?
        let fifthReasonButtonTapped: AnyPublisher<Void, Never>?
        let sixthReasonButtonTapped: AnyPublisher<Void, Never>?
    }
    
    struct Output {
        let getPostData: PassthroughSubject<PostDetailResponseDTO, Never>
        let toggleLikeButton: PassthroughSubject<Bool, Never>
        let getPostReplyData: PassthroughSubject<[PostReplyResponseDTO], Never>
        let toggleCommentLikeButton: PassthroughSubject<Bool, Never>
        let clickedButtonState: PassthroughSubject<Int, Never>
    }
    
    func transform(from input: Input, cancelBag: CancelBag) -> Output {
        input.viewUpdate?
            .sink { value in
                Task {
                    do {
                        if let accessToken = KeychainWrapper.loadToken(forKey: "accessToken") {
                            let postResult = try await
                            self.getPostDetailDataAPI(accessToken: accessToken, contentId: value)
                            if let data = postResult?.data {
                                self.isLikeButtonClicked = data.isLiked
                                self.getPostData.send(data)
                                
                                Amplitude.instance().logEvent("click_post_view")
                            }
                        }
                    } catch {
                        print(error)
                    }
                }
            }
            .store(in: self.cancelBag)
        
        input.likeButtonTapped?
            .sink {  value in
                Task {
                    do {
                        if value.0 {
                            let statusCode = try await self.deleteLikeButtonAPI(contentId: value.1)?.status
                            if statusCode == 200 {
                                self.toggleLikeButton.send(!value.0)
                            }
                        } else {
                            let statusCode = try await self.postLikeButtonAPI(contentId: value.1)?.status
                            if statusCode == 201 {
                                self.toggleLikeButton.send(value.0)
                                
                                Amplitude.instance().logEvent("click_post_like")
                            }
                        }
                    } catch {
                        print(error)
                    }
                }
            }
            .store(in: self.cancelBag)
        
        input.collectionViewUpdata?
            .sink { [self] value in
                Task {
                    do {
                        if let accessToken = KeychainWrapper.loadToken(forKey: "accessToken") {
                            let postReplyResult = try await
                            self.getPostReplyDataAPI(accessToken: accessToken, contentId: value)
                            if let data = postReplyResult?.data {
                                if let lastCommentId = data.last?.commentId {
                                    self.cursor = lastCommentId
                                }
                                if self.cursor == -1 {
                                    self.postReplyDatas = []
                                    
                                    self.postReplyData = data
                                    self.getPostReplyData.send(data)
                                    
                                    postReplyDatas.append(contentsOf: postReplyData)
                                } else {
                                    self.postReplyData = data
                                    self.getPostReplyData.send(data)
                                    
                                    postReplyDatas.append(contentsOf: postReplyData)
                                }
                            }
                        }
                    } catch {
                        print(error)
                    }
                }
            }
            .store(in: self.cancelBag)
        input.commentLikeButtonTapped?
            .sink {  value in
                Task {
                    do {
                        if value.0 == true {
                            let statusCode = try await self.deleteCommentLikeButtonAPI(commentId: value.1)?.status
                            if statusCode == 201 {
                                self.toggleCommentLikeButton.send(!value.0)
                            }
                        } else {
                            let statusCode = try await self.postCommentLikeButtonAPI(commentId: value.1, alarmText: value.2)?.status
                            if statusCode == 201 {
                                self.toggleCommentLikeButton.send(value.0)
                                
                                Amplitude.instance().logEvent("click_reply_like")
                            }
                        }
                    } catch {
                        print(error)
                    }
                }
            }
            .store(in: self.cancelBag)
        
        input.firstReasonButtonTapped?
            .sink { [weak self] _ in
                self?.isFirstReasonChecked.toggle()
                self?.clickedRadioButtonState.send(1)
            }
            .store(in: cancelBag)
        
        input.secondReasonButtonTapped?
            .sink { [weak self] _ in
                self?.isSecondReasonChecked.toggle()
                self?.clickedRadioButtonState.send(2)
            }
            .store(in: cancelBag)
        
        input.thirdReasonButtonTapped?
            .sink { [weak self] _ in
                self?.isThirdReasonChecked.toggle()
                self?.clickedRadioButtonState.send(3)
            }
            .store(in: cancelBag)
        
        input.fourthReasonButtonTapped?
            .sink { [weak self] _ in
                self?.isFourthReasonChecked.toggle()
                self?.clickedRadioButtonState.send(4)
            }
            .store(in: cancelBag)
        
        input.fifthReasonButtonTapped?
            .sink { [weak self] _ in
                self?.isFifthReasonChecked.toggle()
                self?.clickedRadioButtonState.send(5)
            }
            .store(in: cancelBag)
        
        input.sixthReasonButtonTapped?
            .sink { [weak self] _ in
                self?.isSixthReasonChecked.toggle()
                self?.clickedRadioButtonState.send(6)
            }
            .store(in: cancelBag)
        
        return Output(getPostData: getPostData,
                      toggleLikeButton: toggleLikeButton,
                      getPostReplyData: getPostReplyData,
                      toggleCommentLikeButton: toggleCommentLikeButton,
                      clickedButtonState: clickedRadioButtonState)
    }
    
    
    init(networkProvider: NetworkServiceType) {
        self.networkProvider = networkProvider
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Network

extension PostDetailViewModel {
    private func getPostDetailDataAPI(accessToken: String, contentId: Int) async throws -> BaseResponse<PostDetailResponseDTO>? {
        do {
            let result: BaseResponse<PostDetailResponseDTO>? = try
            await self.networkProvider.donNetwork(type: .get, baseURL: Config.baseURL.dropLast() + "2/content/\(contentId)/detail", accessToken: accessToken, body: EmptyBody(), pathVariables: ["":""])
            return result
        } catch {
            return nil
        }
    }
    
    private func getPostReplyDataAPI(accessToken: String, contentId: Int) async throws -> BaseResponse<[PostReplyResponseDTO]>? {
        do {
            let result: BaseResponse<[PostReplyResponseDTO]>? = try await
            self.networkProvider.donNetwork(type: .get,
                                            baseURL: Config.baseURL + "/content/\(contentId)/comments",
                                            accessToken: accessToken,
                                            body: EmptyBody(),
                                            pathVariables: ["cursor":"\(cursor)"])
            return result
        } catch {
            return nil
        }
    }
    
    func postDownTransparency(accessToken: String, alarmTriggerType: String, targetMemberId: Int, alarmTriggerId: Int, ghostReason: String) async throws -> BaseResponse<EmptyResponse>? {
        do {
            let result: BaseResponse<EmptyResponse>? = try await
            self.networkProvider.donNetwork(type: .post,
                                            baseURL: Config.baseURL + "/ghost2",
                                            accessToken: accessToken,
                                            body: PostTransparencyRequestDTO(
                                                alarmTriggerType: alarmTriggerType,
                                                targetMemberId: targetMemberId,
                                                alarmTriggerId: alarmTriggerId,
                                                ghostReason: ghostReason
                                            ),
                                            pathVariables: ["":""])
            return result
        } catch {
            return nil
        }
    }
    
    private func postLikeButtonAPI(contentId: Int) async throws -> BaseResponse<EmptyResponse>? {
        do {
            guard let accessToken = KeychainWrapper.loadToken(forKey: "accessToken") else { return nil }
            let requestDTO = ContentLikeRequestDTO(alarmTriggerType: "contentLiked")
            let data: BaseResponse<EmptyResponse>? = try await
            self.networkProvider.donNetwork(
                type: .post,
                baseURL: Config.baseURL + "/content/\(contentId)/liked",
                accessToken: accessToken,
                body: requestDTO,
                pathVariables: ["":""]
            )
            print ("👻👻👻👻👻게시물 좋아요 버튼 클릭👻👻👻👻👻")
            return data
        } catch {
            return nil
        }
    }
    
    private func deleteLikeButtonAPI(contentId: Int) async throws -> BaseResponse<EmptyResponse>? {
        do {
            guard let accessToken = KeychainWrapper.loadToken(forKey: "accessToken") else { return nil }
            let data: BaseResponse<EmptyResponse>? = try await
            self.networkProvider.donNetwork(
                type: .delete,
                baseURL: Config.baseURL + "/content/\(contentId)/unliked",
                accessToken: accessToken,
                body: EmptyBody(),
                pathVariables: ["":""]
            )
            print ("👻👻👻👻👻게시물 좋아요 취소 버튼 클릭👻👻👻👻👻")
            return data
        } catch {
            return nil
        }
    }
    
    private func postCommentLikeButtonAPI(commentId: Int, alarmText: String)  async throws -> BaseResponse<EmptyResponse>? {
        do {
            guard let accessToken = KeychainWrapper.loadToken(forKey: "accessToken") else { return nil }
            let requestDTO = CommentLikeRequestDTO(notificationTriggerType: "commentLiked", notificationText: alarmText)
            let data: BaseResponse<EmptyResponse>? = try await
            self.networkProvider.donNetwork(
                type: .post,
                baseURL: Config.baseURL + "/comment/\(commentId)/liked",
                accessToken: accessToken,
                body: requestDTO,
                pathVariables: ["":""]
            )
            print ("👻👻👻👻👻답글 좋아요 버튼 클릭👻👻👻👻👻")
            return data
        } catch {
            return nil
        }
    }
    
    private func deleteCommentLikeButtonAPI(commentId: Int)  async throws -> BaseResponse<EmptyResponse>? {
        do {
            guard let accessToken = KeychainWrapper.loadToken(forKey: "accessToken") else { return nil }
            let data: BaseResponse<EmptyResponse>? = try await
            self.networkProvider.donNetwork(
                type: .delete,
                baseURL: Config.baseURL + "/comment/\(commentId)/unliked",
                accessToken: accessToken,
                body: EmptyBody(),
                pathVariables: ["":""]
            )
            print ("👻👻👻👻👻답글 좋아요 취소 버튼 클릭👻👻👻👻👻")
            return data
        } catch {
            return nil
        }
    }
}
