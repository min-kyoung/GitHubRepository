# GitHubRepository
## Description
* GitHub API를 이용해서 애플의 GitHub 계정에 있는 repository를 불러오는 프로젝트다.
  * 데이터를 가져오는 부분은 RxSwift를 통해 진행한다.
* 어플 실행 후 화면을 아래로 당겨 refreshControl이 실행되면 repository를 보여준다.
#### 구현화면 <br> 
<img src="https://user-images.githubusercontent.com/62936197/157023848-f5bdacda-c5cf-408e-975c-0f91267e1d98.png" width="150" height="320"> 　
<img src="https://user-images.githubusercontent.com/62936197/157023859-aab6d07e-c9da-4daf-833b-628ee6c4fb39.png" width="150" height="320">

## Prerequisite
* XCode Version 13.2.1에서 개발을 진행한다
* 스토리보드를 사용하지 않기 위한 초기 셋팅이 필요하다.
  1. Main.storyboard를 삭제한다.
  2. info.plist에 있는 Main.storyboard와 관련된 항목을 삭제한다.
     <img src="https://user-images.githubusercontent.com/62936197/149618014-9c2a58e8-9bb7-49f7-8552-1f381a08b63a.png" width="700" height="130">
     <img src="https://user-images.githubusercontent.com/62936197/149618059-abea1cef-5272-4abf-bfa2-ae300ab9def0.png" width="700" height="20">
  3. ViewController의 이름을 RepositoryListViewController로 변경하여 사용한다.
  4. SceneDelegate에서 생성할 ViewController가 나타날 수 있도록 설정한다.
      ```swift
      class SceneDelegate: UIResponder, UIWindowSceneDelegate {
          var window: UIWindow?

          func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
              guard let windowScene = (scene as? UIWindowScene) else { return }
  
              self.window = UIWindow(windowScene: windowScene)
        
              let rootViewController = RepositoryListViewController()
              let rootNavigationController = UINavigationController(rootViewController: rootViewController)
        
              self.window?.rootViewController = rootNavigationController
              self.window?.makeKeyAndVisible()
          }
      }
      ```
* SnapKit을 설치한다. 
  * SnapKit은 UI를 쉽기 그리기 위해 사용된다.
  * **File > Add Packages**에서 아래 openAPI를 설치한다.
     ```
     https://github.com/SnapKit/SnapKit.git
     ```
## Usage
* UIRefreshControl
  * iOS 6 버전 이상부터 사용이 가능하다.
  ```swift 
  private lazy var refreshControl: UIRefreshControl = {
        self.refreshControl = UIRefreshControl()
        
        let refreshControl = self.refreshControl!
        refreshControl.backgroundColor = .white
        refreshControl.tintColor = .darkGray
        refreshControl.attributedTitle = NSAttributedString(string: "당겨서 새로고침")
        // refreshControl을 당겼을 때 API call
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
  }()
  ``` 
* async
  * 비동기 코드를 동기적으로 작성하게 해주는 swift extension
  ```swift
  @objc func refresh() {
      // API 네트워킹
      DispatchQueue.global(qos: .background).async {[weak self] in
          guard let self = self else { return }
          self.fetchRepositories(of: self.organization)
      }
  }
  ```
* RxSwift의 Observable을 이용한 네트워크 통신
  * 네트워크 통신을 해서 json을 가지고 와 디코딩하고, 위에서 생성한 subject에 onNext한다.
  ```swift
  func fetchRepositories(of organization: String) {
      Observable.from([organization]) // 함수에 넣을 "Apple"을 array 형태로 받을 from 사용
          // URL 형태로 변환
          .map { organization -> URL in
              return URL(string: "https://api.github.com/orgs/\(organization)/repos")! 
          }
          // URLRequest로 변환
          .map { url -> URLRequest in
              var request = URLRequest(url: url) 
              request.httpMethod = "GET"
              return request
          }
          // response를 rx로 변환
          .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
              return URLSession.shared.rx.response(request: request) 
              // => response는 URLResponse를 받아서 방금 선언한 URLResponse와 data의 튜플을 가지는 observable sequence로 반환
          }
          .filter { responds, _ in
              return 200..<300 ~= responds.statusCode // 정상적인 응답일 경우에만 넘겨줌
          }
          .map { _, data -> [[String: Any]] in
              guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
                    let result = json as? [[String: Any]] else {
                        return []
              }
              return result
          }
          .filter { result in
              result.count > 0 // 빈 array는 무시하겠다는 뜻
          }
          // dictionary 형태를 repositoty 형태로 변환
          .map { objects in
              return objects.compactMap { dic -> Repository? in 
                  // compactMap을 사용하면 자동적으로 nil 값은 제거된다.
                  guard let id = dic["id"] as? Int,
                        let name = dic["name"] as? String,
                        let description = dic["description"] as? String,
                        let stargazersCount = dic["stargazers_count"] as? Int,
                        let language = dic["language"] as? String else {
                      return nil
                  }
                    
                  return Repository(id: id, name: name, description: description, stargazersCount: stargazersCount, language: language)
              }
          }
          .subscribe(onNext: {[weak self] newRepositories in
              self?.repositories.onNext(newRepositories)
                
              DispatchQueue.main.async {
                  self?.tableView.reloadData()
                  self?.refreshControl?.endRefreshing()
              }
          })
          .disposed(by: disposeBag)
  }
  ``` 
## Files
> RepositoryListViewController.swift
  * 앱을 실행하면 보여질 메인 화면
  * refreshControl을 실행하면 API 통신을 통해 GitHub repository를 보여준다.
> RepositoryListCell.swift
  * RepositoryListViewController에 register되어있는 tableViewCell
  * 화면에 보여줄 label 및 image를 정의하고 layout을 조정한다.
> Repository.swift
  * API를 받아와 보여줄 객체 정의
  * CodingKeys를 통해 임의로 정의한 이름과 실제 API에 사용되는 이름을 맞춰준다.
