//
//  MyPageMemberDataViewModel.swift
//  DontBe-iOS
//
//  Created by 변상우 on 1/14/24.
//

import Combine
import Foundation

final class MyPageViewModel: ViewModelType {
    
    private let cancelBag = CancelBag()
    private let networkProvider: NetworkServiceType
    
    private var getProfileData = PassthroughSubject<MypageProfileResponseDTO, Never>()
    private var getContentData = PassthroughSubject<[MyPageMemberContentResponseDTO], Never>()
    private var getCommentData = PassthroughSubject<[MyPageMemberCommentResponseDTO], Never>()
    
    var myPageProfileData: [MypageProfileResponseDTO] = []
    
    var myPageContentData: [MyPageMemberContentResponseDTO] = []
    var myPageContentDatas: [MyPageMemberContentResponseDTO] = []
    
    var myPageCommentData: [MyPageMemberCommentResponseDTO] = []
    var myPageCommentDatas: [MyPageMemberCommentResponseDTO] = []
    
    private var memberId: Int = 0
    var contentCursor: Int = -1
    var commentCursor: Int = -1
    
    struct Input {
        let viewUpdate: AnyPublisher<(Int,Int,Int,Int), Never>
    }
    
    struct Output {
        let getProfileData: PassthroughSubject<MypageProfileResponseDTO, Never>
        let getContentData: PassthroughSubject<[MyPageMemberContentResponseDTO], Never>
        let getCommentData: PassthroughSubject<[MyPageMemberCommentResponseDTO], Never>
    }
    
    func transform(from input: Input, cancelBag: CancelBag) -> Output {
        input.viewUpdate
            .sink { [self] value in
                if value.0 == 1 {
                    // 유저 프로필 조회 API
                    Task {
                        do {
                            if let accessToken = KeychainWrapper.loadToken(forKey: "accessToken") {
                                let profileResult = try await self.getProfileInfoAPI(accessToken: accessToken, memberId: value.1)
                                if let data = profileResult?.data {
                                    self.myPageProfileData.append(data)
                                    self.getProfileData.send(data)
                                }
                            }
                        } catch {
                            print(error)
                        }
                    }
                    
                    // 유저에 해당하는 게시글 리스트 조회
                    Task {
                        do {
                            if let accessToken = KeychainWrapper.loadToken(forKey: "accessToken") {
                                let contentResult = try await self.getMemberContentAPI(accessToken: accessToken, memberId: value.1, contentCursor: value.3)
                                
                                if let data = contentResult?.data {
                                    self.getContentData.send(self.myPageContentDatas)
                                }
                            }
                        } catch {
                            print(error)
                        }
                    }
                    
                    // 유저에 해당하는 답글 리스트 조회
                    Task {
                        do {
                            if let accessToken = KeychainWrapper.loadToken(forKey: "accessToken") {
                                let commentResult = try await self.getMemberCommentAPI(accessToken: accessToken, memberId: value.1, commentCursor: value.2)
                                
                                if let data = commentResult?.data {
                                    self.getCommentData.send(self.myPageCommentDatas)
                                }
                                
                            }
                        } catch {
                            print(error)
                        }
                    }
                }
            }
            .store(in: self.cancelBag)
        
        return Output(getProfileData: getProfileData,
                      getContentData: getContentData,
                      getCommentData: getCommentData)
    }
    
    init(networkProvider: NetworkServiceType) {
        self.networkProvider = networkProvider
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MyPageViewModel {
    private func getProfileInfoAPI(accessToken: String, memberId: Int) async throws -> BaseResponse<MypageProfileResponseDTO>? {
        do {
            let result: BaseResponse<MypageProfileResponseDTO>? = try await self.networkProvider.donNetwork(
                type: .get,
                baseURL: Config.baseURL + "/viewmember/\(memberId)",
                accessToken: accessToken,
                body: EmptyBody(),
                pathVariables: ["":""])
            UserDefaults.standard.set(result?.data?.memberGhost ?? 0, forKey: "memberGhost")
            return result
        } catch {
            return nil
        }
    }
    
    private func getMemberContentAPI(accessToken: String, memberId: Int, contentCursor: Int) async throws -> BaseResponse<[MyPageMemberContentResponseDTO]>? {
        do {
            let result: BaseResponse<[MyPageMemberContentResponseDTO]>? = try await self.networkProvider.donNetwork(
                type: .get,
                baseURL: Config.baseURL + "/member/\(memberId)/member-contents",
                accessToken: accessToken,
                body: EmptyBody(),
                pathVariables:["cursor":"\(contentCursor)"])
            if let data = result?.data {
                if contentCursor == -1 {
                    self.myPageContentDatas = []
                    
                    var tempArrayData: [MyPageMemberContentResponseDTO] = []
                    
                    for content in data {
                        tempArrayData.append(content)
                    }
                    self.myPageContentData = tempArrayData
                    myPageContentDatas.append(contentsOf: myPageContentData)
                } else {
                    var tempArrayData: [MyPageMemberContentResponseDTO] = []
                    
                    if data.isEmpty {
                        self.contentCursor = -1
                    } else {
                        for content in data {
                            tempArrayData.append(content)
                        }
                        self.myPageContentData = tempArrayData
                        myPageContentDatas.append(contentsOf: myPageContentData)
                    }
                }
            }
            return result
        } catch {
            return nil
        }
    }
    
    private func getMemberCommentAPI(accessToken: String, memberId: Int, commentCursor: Int) async throws -> BaseResponse<[MyPageMemberCommentResponseDTO]>? {
        do {
            let result: BaseResponse<[MyPageMemberCommentResponseDTO]>? = try await self.networkProvider.donNetwork(
                type: .get,
                baseURL: Config.baseURL + "/member/\(memberId)/member-comments",
                accessToken: accessToken,
                body: EmptyBody(),
                pathVariables:["cursor":"\(commentCursor)"])
            if let data = result?.data {
                if commentCursor == -1 {
                    self.myPageCommentDatas = []
                    
                    var tempArrayData: [MyPageMemberCommentResponseDTO] = []
                    
                    for comment in data {
                        tempArrayData.append(comment)
                    }
                    self.myPageCommentData = tempArrayData
                    myPageCommentDatas.append(contentsOf: myPageCommentData)
                } else {
                    var tempArrayData: [MyPageMemberCommentResponseDTO] = []
                    
                    for comment in data {
                        tempArrayData.append(comment)
                    }
                    self.myPageCommentData = tempArrayData
                    myPageCommentDatas.append(contentsOf: myPageCommentData)
                }
            }
            return result
        } catch {
            return nil
        }
    }
}
