//
//  MyPageViewController.swift
//  DontBe-iOS
//
//  Created by 변상우 on 1/11/24.
//

import Combine
import SafariServices
import UIKit

import SnapKit

final class MyPageViewController: UIViewController {
    
    // MARK: - Properties
    
    let customerCenterURL = URL(string: StringLiterals.MyPage.myPageCustomerURL)
    let feedbackURL = URL(string: StringLiterals.MyPage.myPageFeedbackURL)
    let warnUserURL = URL(string: StringLiterals.Network.warnUserGoogleFormURL)
    
    private var cancelBag = CancelBag()
    var viewModel: MyPageViewModel
    let homeViewModel = HomeViewModel(networkProvider: NetworkService())
    
    private lazy var firstReason = self.transparentReasonView.firstReasonView.radioButton.publisher(for: .touchUpInside).map { _ in }.eraseToAnyPublisher()
    private lazy var secondReason = self.transparentReasonView.secondReasonView.radioButton.publisher(for: .touchUpInside).map { _ in }.eraseToAnyPublisher()
    private lazy var thirdReason = self.transparentReasonView.thirdReasonView.radioButton.publisher(for: .touchUpInside).map { _ in }.eraseToAnyPublisher()
    private lazy var fourthReason = self.transparentReasonView.fourthReasonView.radioButton.publisher(for: .touchUpInside).map { _ in }.eraseToAnyPublisher()
    private lazy var fifthReason = self.transparentReasonView.fifthReasonView.radioButton.publisher(for: .touchUpInside).map { _ in }.eraseToAnyPublisher()
    private lazy var sixthReason = self.transparentReasonView.sixthReasonView.radioButton.publisher(for: .touchUpInside).map { _ in }.eraseToAnyPublisher()
    
    var memberId: Int = loadUserData()?.memberId ?? 0
    var memberProfileImage: String = loadUserData()?.userProfileImage ?? ""
    var contentId: Int = 0
    var alarmTriggerType: String = ""
    var targetMemberId: Int = 0
    var alarmTriggerdId: Int = 0
    var ghostReason: String = ""
    
    var commentDatas: [MyPageMemberCommentResponseDTO] = []
    var contentDatas: [MyPageMemberContentResponseDTO] = []
    var commentCursor: Int = -1
    var contentCursor: Int = -1
    
    var currentPage: Int = 0 {
        didSet {
            rootView.myPageScrollView.isScrollEnabled = true
            let direction: UIPageViewController.NavigationDirection = oldValue <= self.currentPage ? .forward : .reverse
            rootView.pageViewController.setViewControllers(
                [rootView.dataViewControllers[self.currentPage]],
                direction: direction,
                animated: true,
                completion: nil
            )
            let navigationBarHeight = self.navigationController?.navigationBar.frame.height ?? 0
            rootView.myPageScrollView.setContentOffset(CGPoint(x: 0, y: -rootView.myPageScrollView.contentInset.top - navigationBarHeight - statusBarHeight), animated: true)
            rootView.myPageContentViewController.homeCollectionView.isScrollEnabled = true
            rootView.myPageScrollView.isScrollEnabled = true
        }
    }
    
    var tabBarHeight: CGFloat = 0
    
    // MARK: - UI Components
    
    let rootView = MyPageView()
    let refreshControl = UIRefreshControl()
    
    var deleteBottomsheet = DontBeBottomSheetView(singleButtonImage: ImageLiterals.Posting.btnDelete)
    var warnBottomsheet = DontBeBottomSheetView(singleButtonImage: ImageLiterals.Posting.btnWarn)
    
    var transparentReasonView = DontBePopupReasonView()
    var deletePostPopupVC = DeletePopupViewController(viewModel: DeletePostViewModel(networkProvider: NetworkService()))
    
    private var uploadToastView: DontBeToastView?
    private var deleteToastView: DontBeDeletePopupView?
    private var alreadyTransparencyToastView: DontBeToastView?
    private var logoutPopupView: DontBePopupView? = nil
    
    let statusBarView = UIView(frame: UIApplication.shared.statusBarFrame)
    private var navigationBackButton: UIButton = {
        let button = UIButton()
        button.setImage(ImageLiterals.Common.btnBackGray, for: .normal)
        return button
    }()

   // MARK: - Life Cycles
    
    override func loadView() {
        super.loadView()
        
        view = rootView
    }
    
    init(viewModel: MyPageViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        getAPI()
        setUI()
        setLayout()
        setDelegate()
        setAddTarget()
        setRefreshControll()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        self.tabBarController?.tabBar.isHidden = false
        self.tabBarController?.tabBar.isTranslucent = true
        
        bindViewModel()
        bindHomeViewModel()
        setNotification()
        
        if loadUserData()?.userProfileImage != self.memberProfileImage {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.refreshData()
            }
        }
        
        let image = ImageLiterals.MyPage.icnMenu
        let renderedImage = image.withRenderingMode(.alwaysOriginal)
        
        // 본인 프로필 화면
        if memberId == loadUserData()?.memberId ?? 0 {
            self.navigationItem.title = StringLiterals.MyPage.MyPageNavigationTitle
            self.tabBarController?.tabBar.isHidden = false
            navigationBackButton.isHidden = true
            let hambergerButton = UIBarButtonItem(image: renderedImage,
                                                  style: .plain,
                                                  target: self,
                                                  action: #selector(myPageHambergerButtonTapped))
            navigationItem.rightBarButtonItem = hambergerButton
        } else {
            // 타 유저 프로필 화면
            self.navigationItem.title = ""
            self.tabBarController?.tabBar.isHidden = true
            navigationBackButton.isHidden = false
            let hambergerButton = UIBarButtonItem(image: renderedImage,
                                                  style: .plain,
                                                  target: self,
                                                  action: #selector(otherPageHambergerButtonTapped))
            navigationItem.rightBarButtonItem = hambergerButton
        }
        
        self.navigationController?.navigationBar.backgroundColor = .donBlack
        self.navigationController?.navigationBar.barTintColor = .donBlack
        self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.donWhite]
        self.navigationController?.navigationBar.isHidden = false
        self.navigationController?.navigationBar.barTintColor = .clear
        self.navigationItem.hidesBackButton = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        self.tabBarController?.tabBar.isTranslucent = false
        navigationBackButton.isHidden = true
        self.navigationController?.navigationBar.barTintColor = .donWhite
        statusBarView.removeFromSuperview()
        
        removeNotification()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let safeAreaHeight = view.safeAreaInsets.bottom
        let tabBarHeight: CGFloat = 70.0
        
        self.tabBarHeight = tabBarHeight + safeAreaHeight
    }
}

// MARK: - Extensions

extension MyPageViewController {
    private func setUI() {
        self.view.backgroundColor = .donBlack
        
        deletePostPopupVC.modalPresentationStyle = .overFullScreen
    }
    
    private func setLayout() {
        self.navigationController?.navigationBar.addSubviews(navigationBackButton)
        navigationBackButton.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().inset(16.adjusted)
        }
        rootView.pageViewController.view.snp.makeConstraints {
            $0.top.equalTo(rootView.segmentedControl.snp.bottom).offset(2.adjusted)
            $0.leading.trailing.equalToSuperview()
        }
    }
    
    private func setDelegate() {
        rootView.myPageScrollView.delegate = self
        rootView.pageViewController.delegate = self
        rootView.pageViewController.dataSource = self
        transparentReasonView.delegate = self
    }
    
    private func setNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(pushViewController), name: MyPageContentViewController.pushViewController, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: MyPageContentViewController.reloadData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadCommentData(_:)), name: MyPageCommentViewController.reloadCommentData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadContentData(_:)), name: MyPageContentViewController.reloadContentData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(warnButtonTapped), name: MyPageContentViewController.warnUserButtonTapped, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(contentGhostButtonTapped), name: MyPageContentViewController.ghostButtonTapped, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(commentGhostButtonTapped), name: MyPageCommentViewController.ghostButtonTapped, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showDeleteToast(_:)), name: DeletePopupViewController.showDeletePostToastNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showDeleteToast(_:)), name: DeleteReplyPopupViewController.showDeleteReplyToastNotification, object: nil)
    }
    
    private func removeNotification() {
        NotificationCenter.default.removeObserver(self, name: MyPageContentViewController.pushViewController, object: nil)
        NotificationCenter.default.removeObserver(self, name: MyPageContentViewController.reloadData, object: nil)
        NotificationCenter.default.removeObserver(self, name: MyPageCommentViewController.reloadCommentData, object: nil)
        NotificationCenter.default.removeObserver(self, name: MyPageContentViewController.reloadContentData, object: nil)
        NotificationCenter.default.removeObserver(self, name: MyPageContentViewController.warnUserButtonTapped, object: nil)
        NotificationCenter.default.removeObserver(self, name: MyPageContentViewController.ghostButtonTapped, object: nil)
        NotificationCenter.default.removeObserver(self, name: MyPageCommentViewController.ghostButtonTapped, object: nil)
        NotificationCenter.default.removeObserver(self, name: DeletePopupViewController.showDeletePostToastNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: DeleteReplyPopupViewController.showDeleteReplyToastNotification, object: nil)
    }
    
    private func setAddTarget() {
        navigationBackButton.addTarget(self, action: #selector(backButtonPressed), for: .touchUpInside)
        rootView.segmentedControl.addTarget(self, action: #selector(changeValue(control:)), for: .valueChanged)
        rootView.myPageContentViewController.firstContentButton.addTarget(self, action: #selector(goToWriteViewController), for: .touchUpInside)
        rootView.myPageBottomsheet.profileEditButton.addTarget(self, action: #selector(profileEditButtonTapped), for: .touchUpInside)
        rootView.myPageBottomsheet.accountInfoButton.addTarget(self, action: #selector(accountInfoButtonTapped), for: .touchUpInside)
        rootView.myPageBottomsheet.feedbackButton.addTarget(self, action: #selector(feedbackButtonTapped), for: .touchUpInside)
        rootView.myPageBottomsheet.customerCenterButton.addTarget(self, action: #selector(customerCenterButtonTapped), for: .touchUpInside)
        rootView.myPageBottomsheet.logoutButton.addTarget(self, action: #selector(logoutButtonTapped), for: .touchUpInside)
        rootView.warnBottomsheet.warnButton.addTarget(self, action: #selector(warnButtonTapped), for: .touchUpInside)
    }
    
    private func setRefreshControll() {
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        rootView.myPageScrollView.refreshControl = refreshControl
        refreshControl.tintColor = .donGray1
        refreshControl.backgroundColor = .donBlack
    }
    
    @objc
    func refreshData() {
        DispatchQueue.main.async {
            self.contentCursor = -1
            self.commentCursor = -1
            self.bindViewModel()
        }
        self.perform(#selector(self.finishedRefreshing), with: nil, afterDelay: 0.1)
    }
    
    @objc
    func finishedRefreshing() {
        refreshControl.endRefreshing()
    }
    
    @objc func showDeleteToast(_ notification: Notification) {
        if let showToast = notification.userInfo?["showDeleteToast"] as? Bool {
            if showToast == true {
                DispatchQueue.main.async {
                    self.deleteToastView = DontBeDeletePopupView()
                    
                    self.view.addSubviews(self.deleteToastView ?? DontBeDeletePopupView())
                    
                    self.deleteToastView?.snp.makeConstraints {
                        $0.leading.trailing.equalToSuperview().inset(24.adjusted)
                        $0.centerY.equalTo(self.view.safeAreaLayoutGuide)
                        $0.height.equalTo(75.adjusted)
                    }
                    
                    UIView.animate(withDuration: 2.0, delay: 0, options: .curveEaseIn) {
                        self.deleteToastView?.alpha = 0
                    }
                }
            }
        }
    }
    
    func showAlreadyTransparencyToast() {
        DispatchQueue.main.async {
            self.alreadyTransparencyToastView = DontBeToastView()
            self.alreadyTransparencyToastView?.toastLabel.text = StringLiterals.Toast.alreadyTransparency
            self.alreadyTransparencyToastView?.circleProgressBar.alpha = 0
            self.alreadyTransparencyToastView?.checkImageView.alpha = 1
            self.alreadyTransparencyToastView?.checkImageView.image = ImageLiterals.Home.icnNotice
            self.alreadyTransparencyToastView?.container.backgroundColor = .donPrimary
            
            self.view.addSubviews(self.alreadyTransparencyToastView ?? DontBeToastView())
            
            self.alreadyTransparencyToastView?.snp.remakeConstraints {
                $0.leading.trailing.equalToSuperview().inset(16.adjusted)
                $0.bottom.equalToSuperview().inset(20.adjusted)
            }
            
            self.alreadyTransparencyToastView?.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(16.adjusted)
                $0.bottom.equalTo(self.tabBarHeight.adjusted).inset(6.adjusted)
                $0.height.equalTo(44.adjusted)
            }
            
            UIView.animate(withDuration: 1.5, delay: 1, options: .curveEaseIn) {
                self.alreadyTransparencyToastView?.alpha = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.alreadyTransparencyToastView?.removeFromSuperview()
            }
        }
    }
    
    func showLogoutPopupView() {
        self.logoutPopupView = DontBePopupView(popupTitle: StringLiterals.MyPage.myPageLogoutPopupTitleLabel,
                                               popupContent: StringLiterals.MyPage.myPageLogoutPopupContentLabel,
                                               leftButtonTitle: StringLiterals.MyPage.myPageLogoutPopupLeftButtonTitle,
                                               rightButtonTitle: StringLiterals.MyPage.myPageLogoutPopupRightButtonTitle)
        
        if let popupView = self.logoutPopupView {
            if let window = UIApplication.shared.keyWindowInConnectedScenes {
                window.addSubviews(popupView)
            }
            
            popupView.delegate = self
            
            popupView.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
        }
    }
    
    func bindViewModel() {
        let input = MyPageViewModel.Input(viewUpdate: Just((1, self.memberId, self.commentCursor, self.contentCursor)).eraseToAnyPublisher())
        
        let output = viewModel.transform(from: input, cancelBag: cancelBag)
        
        output.getProfileData
            .receive(on: RunLoop.main)
            .sink { data in
                self.rootView.myPageContentViewController.profileData = self.viewModel.myPageProfileData
                self.rootView.myPageCommentViewController.profileData = self.viewModel.myPageProfileData
                self.bindProfileData(data: data)
            }
            .store(in: self.cancelBag)
        
        output.getContentData
            .receive(on: RunLoop.main)
            .sink { data in
                self.rootView.myPageContentViewController.contentDatas = data
                self.viewModel.contentCursor = self.contentCursor
                if data.isEmpty {
                    self.viewModel.contentCursor = -1
                } else {
                    self.viewModel.contentCursor = self.contentCursor
                }
                if !data.isEmpty {
                    self.rootView.myPageContentViewController.noContentLabel.isHidden = true
                    self.rootView.myPageContentViewController.firstContentButton.isHidden = true
                } else {
                    if loadUserData()?.memberId != self.memberId {
                        self.rootView.myPageContentViewController.noContentLabel.isHidden = false
                        self.rootView.myPageContentViewController.firstContentButton.isHidden = true
                    } else {
                        self.rootView.myPageContentViewController.noContentLabel.isHidden = false
                        self.rootView.myPageContentViewController.firstContentButton.isHidden = false
                    }
                }
                DispatchQueue.main.async {
                    self.rootView.myPageContentViewController.homeCollectionView.reloadData()
                }
            }
            .store(in: self.cancelBag)
        
        output.getCommentData
            .receive(on: RunLoop.main)
            .sink { data in
                self.rootView.myPageCommentViewController.commentDatas = data
                if !data.isEmpty {
                    self.rootView.myPageCommentViewController.noCommentLabel.isHidden = true
                } else {
                    self.rootView.myPageCommentViewController.noCommentLabel.isHidden = false
                }
                DispatchQueue.main.async {
                    self.rootView.myPageCommentViewController.homeCollectionView.reloadData()
                }
            }
            .store(in: self.cancelBag)
    }
    
    private func bindHomeViewModel() {
        let input = HomeViewModel.Input(
            viewUpdate: nil,
            likeButtonTapped: nil,
            firstReasonButtonTapped: firstReason,
            secondReasonButtonTapped: secondReason,
            thirdReasonButtonTapped: thirdReason,
            fourthReasonButtonTapped: fourthReason,
            fifthReasonButtonTapped: fifthReason,
            sixthReasonButtonTapped: sixthReason)
        
        let output = homeViewModel.transform(from: input, cancelBag: cancelBag)
        
        output.clickedButtonState
            .sink { [weak self] index in
                guard let self = self else { return }
                let radioSelectedButtonImage = ImageLiterals.TransparencyInfo.btnRadioSelected
                let radioButtonImage = ImageLiterals.TransparencyInfo.btnRadio
                self.transparentReasonView.warnLabel.isHidden = true
                
                switch index {
                case 1:
                    self.transparentReasonView.firstReasonView.radioButton.setImage(radioSelectedButtonImage, for: .normal)
                    self.transparentReasonView.secondReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.thirdReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.fourthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.fifthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.sixthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    ghostReason = self.transparentReasonView.firstReasonView.reasonLabel.text ?? ""
                case 2:
                    self.transparentReasonView.firstReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.secondReasonView.radioButton.setImage(radioSelectedButtonImage, for: .normal)
                    self.transparentReasonView.thirdReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.fourthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.fifthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.sixthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    ghostReason = self.transparentReasonView.secondReasonView.reasonLabel.text ?? ""
                case 3:
                    self.transparentReasonView.firstReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.secondReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.thirdReasonView.radioButton.setImage(radioSelectedButtonImage, for: .normal)
                    self.transparentReasonView.fourthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.fifthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.sixthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    ghostReason = self.transparentReasonView.thirdReasonView.reasonLabel.text ?? ""
                case 4:
                    self.transparentReasonView.firstReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.secondReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.thirdReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.fourthReasonView.radioButton.setImage(radioSelectedButtonImage, for: .normal)
                    self.transparentReasonView.fifthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.sixthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    ghostReason = self.transparentReasonView.fourthReasonView.reasonLabel.text ?? ""
                case 5:
                    self.transparentReasonView.firstReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.secondReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.thirdReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.fourthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.fifthReasonView.radioButton.setImage(radioSelectedButtonImage, for: .normal)
                    self.transparentReasonView.sixthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    ghostReason = self.transparentReasonView.fifthReasonView.reasonLabel.text ?? ""
                case 6:
                    self.transparentReasonView.firstReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.secondReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.thirdReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.fourthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.fifthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
                    self.transparentReasonView.sixthReasonView.radioButton.setImage(radioSelectedButtonImage, for: .normal)
                    ghostReason = self.transparentReasonView.sixthReasonView.reasonLabel.text ?? ""
                default:
                    break
                }
            }
            .store(in: self.cancelBag)
    }
    
    private func bindProfileData(data: MypageProfileResponseDTO) {
        self.rootView.myPageProfileView.profileImageView.load(url: data.memberProfileUrl)
        self.rootView.myPageProfileView.userNickname.text = data.nickname
        self.rootView.myPageProfileView.userIntroduction.text = data.memberIntro
        self.rootView.myPageProfileView.transparencyValue = data.memberGhost
        
        if data.memberId != loadUserData()?.memberId ?? 0 {
            self.rootView.myPageContentViewController.noContentLabel.text = "아직 \(data.nickname)" + StringLiterals.MyPage.myPageNoContentOtherLabel
            self.rootView.myPageCommentViewController.noCommentLabel.text = "아직 \(data.nickname)" + StringLiterals.MyPage.myPageNoCommentOtherLabel
        } else {
            self.rootView.myPageContentViewController.noContentLabel.text = "\(data.nickname)" + StringLiterals.MyPage.myPageNoContentLabel
            self.rootView.myPageCommentViewController.noCommentLabel.text = StringLiterals.MyPage.myPageNoCommentLabel
            
            saveUserData(UserInfo(isSocialLogined: true,
                                  isFirstUser: false,
                                  isJoinedApp: true,
                                  isOnboardingFinished: true,
                                  userNickname: data.nickname,
                                  memberId: loadUserData()?.memberId ?? 0,
                                  userProfileImage: data.memberProfileUrl))
        }
    }
    
    @objc
    private func pushViewController(_ notification: Notification) {
        if let contentId = notification.userInfo?["contentId"] as? Int, let profileImageURL = notification.userInfo?["profileImageURL"] as? String {
            let destinationViewController = PostDetailViewController(viewModel: PostDetailViewModel(networkProvider: NetworkService()))
            destinationViewController.contentId = contentId
            destinationViewController.userProfileURL = profileImageURL
            self.navigationController?.pushViewController(destinationViewController, animated: true)
        }
    }
    
    @objc
    func reloadData(_ notification: Notification) {
        bindViewModel()
    }
    
    @objc
    func reloadCommentData(_ notification: Notification) {
        self.commentCursor = notification.userInfo?["commentCursor"] as? Int ?? -1
        bindViewModel()
    }
    
    @objc
    func reloadContentData(_ notification: Notification) {
        self.contentCursor = notification.userInfo?["contentCursor"] as? Int ?? -1
        bindViewModel()
    }
    
    @objc
    private func changeValue(control: UISegmentedControl) {
        self.currentPage = control.selectedSegmentIndex
    }
    
    @objc
    private func myPageHambergerButtonTapped() {
        rootView.myPageBottomsheet.showSettings()
    }
    
    @objc
    private func otherPageHambergerButtonTapped() {
        rootView.warnBottomsheet.deleteButton.removeFromSuperview()
        rootView.warnBottomsheet.showSettings()
    }
    
    @objc
    private func goToWriteViewController() {
        let viewController = WriteViewController(viewModel: WriteViewModel(networkProvider: NetworkService()))
        self.navigationController?.pushViewController(viewController, animated: false)
    }
    
    @objc
    private func profileEditButtonTapped() {
        rootView.myPageBottomsheet.handleDismiss()
        let vc = MyPageEditProfileViewController(viewModel: MyPageProfileViewModel(networkProvider: NetworkService()))
        vc.memberId = self.memberId
        vc.nickname = self.rootView.myPageProfileView.userNickname.text ?? ""
        vc.introText = self.rootView.myPageProfileView.userIntroduction.text ?? ""
        self.navigationController?.pushViewController(vc, animated: false)
    }
    
    @objc
    private func accountInfoButtonTapped() {
        rootView.myPageBottomsheet.handleDismiss()
        let vc = MyPageAccountInfoViewController(viewModel: MyPageAccountInfoViewModel(networkProvider: NetworkService()))
        self.navigationController?.pushViewController(vc, animated: false)
    }
    
    @objc
    private func customerCenterButtonTapped() {
        rootView.myPageBottomsheet.handleDismiss()
        let customerCenterView: SFSafariViewController
        if let customerCenterURL = self.customerCenterURL {
            customerCenterView = SFSafariViewController(url: customerCenterURL)
            self.present(customerCenterView, animated: true, completion: nil)
        }
    }
    
    @objc
    private func logoutButtonTapped() {
        showLogoutPopupView()
    }
    
    @objc
    private func feedbackButtonTapped() {
        rootView.myPageBottomsheet.handleDismiss()
        let feedbackView: SFSafariViewController
        if let feedbackURL = self.feedbackURL {
            feedbackView = SFSafariViewController(url: feedbackURL)
            self.present(feedbackView, animated: true, completion: nil)
        }
    }
    
    @objc
    private func warnButtonTapped() {
        rootView.warnBottomsheet.handleDismiss()
        let warnView: SFSafariViewController
        if let warnURL = self.warnUserURL {
            warnView = SFSafariViewController(url: warnURL)
            self.present(warnView, animated: true, completion: nil)
        }
    }
    
    @objc
    private func contentGhostButtonTapped() {
        self.alarmTriggerType = rootView.myPageContentViewController.alarmTriggerType
        self.targetMemberId = rootView.myPageContentViewController.targetMemberId
        self.alarmTriggerdId = rootView.myPageContentViewController.alarmTriggerdId
        
        if let window = UIApplication.shared.keyWindowInConnectedScenes {
            window.addSubviews(transparentReasonView)
            
            transparentReasonView.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            
            let radioButtonImage = ImageLiterals.TransparencyInfo.btnRadio
            
            self.transparentReasonView.firstReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.secondReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.thirdReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.fourthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.fifthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.sixthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.warnLabel.isHidden = true
            self.ghostReason = ""
        }
    }
    
    @objc
    private func commentGhostButtonTapped() {
        self.alarmTriggerType = rootView.myPageCommentViewController.alarmTriggerType
        self.targetMemberId = rootView.myPageCommentViewController.targetMemberId
        self.alarmTriggerdId = rootView.myPageCommentViewController.alarmTriggerdId
        
        if let window = UIApplication.shared.keyWindowInConnectedScenes {
            window.addSubviews(transparentReasonView)
            
            transparentReasonView.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            
            let radioButtonImage = ImageLiterals.TransparencyInfo.btnRadio
            
            self.transparentReasonView.firstReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.secondReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.thirdReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.fourthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.fifthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.sixthReasonView.radioButton.setImage(radioButtonImage, for: .normal)
            self.transparentReasonView.warnLabel.isHidden = true
            self.ghostReason = ""
        }
    }
    
    private func moveTop() {
        let navigationBarHeight = self.navigationController?.navigationBar.frame.height ?? 0
        rootView.myPageScrollView.setContentOffset(CGPoint(x: 0, y: -rootView.myPageScrollView.contentInset.top - navigationBarHeight - statusBarHeight), animated: true)
    }
    
    @objc
    private func backButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
}

// MARK: - Network

extension MyPageViewController {
    private func getAPI() {
        
    }
}

extension MyPageViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard
            let index = rootView.dataViewControllers.firstIndex(of: viewController),
            index - 1 >= 0
        else { return nil }
        return rootView.dataViewControllers[index - 1]
    }
    
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard
            let index = rootView.dataViewControllers.firstIndex(of: viewController),
            index + 1 < rootView.dataViewControllers.count
        else { return nil }
        return rootView.dataViewControllers[index + 1]
    }
    
    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard
            let viewController = pageViewController.viewControllers?[0],
            let index = rootView.dataViewControllers.firstIndex(of: viewController)
        else { return }
        self.currentPage = index
        rootView.segmentedControl.selectedSegmentIndex = index
    }
}

extension MyPageViewController: UICollectionViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var yOffset = scrollView.contentOffset.y
        let navigationBarHeight = self.navigationController?.navigationBar.frame.height ?? 0
        
        scrollView.isScrollEnabled = true
        rootView.myPageContentViewController.homeCollectionView.isScrollEnabled = false
        rootView.myPageCommentViewController.homeCollectionView.isScrollEnabled = false
        
        if yOffset <= -(navigationBarHeight + statusBarHeight) {
            rootView.myPageContentViewController.homeCollectionView.isScrollEnabled = false
            rootView.myPageCommentViewController.homeCollectionView.isScrollEnabled = false
            yOffset = -(navigationBarHeight + statusBarHeight)
            rootView.segmentedControl.frame.origin.y = yOffset + statusBarHeight + navigationBarHeight
            rootView.segmentedControl.snp.remakeConstraints {
                $0.top.equalTo(rootView.myPageProfileView.snp.bottom)
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(54.adjusted)
            }
            
            rootView.pageViewController.view.snp.remakeConstraints {
                $0.top.equalTo(rootView.segmentedControl.snp.bottom).offset(2.adjusted)
                $0.leading.trailing.equalToSuperview()
                let navigationBarHeight = self.navigationController?.navigationBar.frame.height ?? 0
                $0.height.equalTo(UIScreen.main.bounds.height - statusBarHeight - navigationBarHeight - self.tabBarHeight)
            }
        } else if yOffset >= (rootView.myPageProfileView.frame.height - statusBarHeight - navigationBarHeight) {
            rootView.segmentedControl.frame.origin.y = yOffset - rootView.myPageProfileView.frame.height + statusBarHeight + navigationBarHeight
            rootView.segmentedControl.snp.remakeConstraints {
                $0.top.equalTo(rootView.myPageProfileView.snp.bottom)
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(54.adjusted)
            }
            
            rootView.pageViewController.view.frame.origin.y = yOffset - rootView.myPageProfileView.frame.height + statusBarHeight + navigationBarHeight + rootView.segmentedControl.frame.height
            
            rootView.pageViewController.view.snp.remakeConstraints {
                $0.top.equalTo(rootView.segmentedControl.snp.bottom).offset(2.adjusted)
                $0.leading.trailing.equalToSuperview()
                let navigationBarHeight = self.navigationController?.navigationBar.frame.height ?? 0
                $0.height.equalTo(UIScreen.main.bounds.height - statusBarHeight - navigationBarHeight - self.tabBarHeight)
            }
            
            scrollView.setContentOffset(CGPoint(x: 0, y: yOffset), animated: true)
            
            rootView.myPageContentViewController.homeCollectionView.isScrollEnabled = true
            rootView.myPageContentViewController.homeCollectionView.isUserInteractionEnabled = true
            rootView.myPageCommentViewController.homeCollectionView.isScrollEnabled = true
            rootView.myPageCommentViewController.homeCollectionView.isUserInteractionEnabled = true
        }
    }
}


extension MyPageViewController: DontBePopupDelegate {
    func cancleButtonTapped() {
        self.logoutPopupView?.removeFromSuperview()
    }
    
    func confirmButtonTapped() {
        self.logoutPopupView?.removeFromSuperview()
        self.rootView.myPageBottomsheet.handleDismiss()
        
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            DispatchQueue.main.async {
                let rootViewController = LoginViewController(viewModel: LoginViewModel(networkProvider: NetworkService()))
                sceneDelegate.window?.rootViewController = UINavigationController(rootViewController: rootViewController)
            }
        }
        
        saveUserData(UserInfo(isSocialLogined: false,
                              isFirstUser: false,
                              isJoinedApp: true,
                              isOnboardingFinished: true,
                              userNickname: loadUserData()?.userNickname ?? "",
                              memberId: loadUserData()?.memberId ?? 0,
                              userProfileImage: loadUserData()?.userProfileImage ?? StringLiterals.Network.baseImageURL))
    
        OnboardingViewController.pushCount = 0
    }
}

extension MyPageViewController: DontBePopupReasonDelegate {
    func reasonCancelButtonTapped() {
        transparentReasonView.removeFromSuperview()
    }
    
    func reasonConfirmButtonTapped() {
        if self.ghostReason == "" {
            self.transparentReasonView.warnLabel.isHidden = false
        } else {
            transparentReasonView.removeFromSuperview()
            
            Task {
                do {
                    if let accessToken = KeychainWrapper.loadToken(forKey: "accessToken") {
                        let result = try await homeViewModel.postDownTransparency(accessToken: accessToken,
                                                                                  alarmTriggerType: self.alarmTriggerType,
                                                                                  targetMemberId: self.targetMemberId,
                                                                                  alarmTriggerId: self.alarmTriggerdId,
                                                                                  ghostReason: self.ghostReason)
                        self.bindViewModel()
                        if result?.status == 400 {
                            // 이미 투명도를 누른 대상인 경우, 토스트 메시지 보여주기
                            showAlreadyTransparencyToast()
                        }
                    }
                } catch {
                    print(error)
                }
            }
        }
    }
}
