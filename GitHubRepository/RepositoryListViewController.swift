//
//  RepositoryListViewController.swift
//  GitHubRepository
//
//  Created by 노민경 on 2022/03/05.
//

import UIKit
import RxSwift
import RxCocoa

class RepositoryListViewController: UITableViewController {
    private let organization = "Apple"
    private let repositories = BehaviorSubject<[Repository]>(value: [])
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = organization + "Repositories"
        
        self.refreshControl = UIRefreshControl()
        
        let refreshControl = self.refreshControl!
        refreshControl.backgroundColor = .white
        refreshControl.tintColor = .darkGray
        refreshControl.attributedTitle = NSAttributedString(string: "당겨서 새로고침")
        // refreshControl을 당겼을 때 API call
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
        tableView.register(RepositoryListCell.self, forCellReuseIdentifier: "RepositoryListCell")
        tableView.rowHeight = 140
    }
    
    @objc func refresh() {
        // API 네트워킹
        DispatchQueue.global(qos: .background).async {[weak self] in
            guard let self = self else { return }
            self.fetchRepositories(of: self.organization)
        }
    }
    
    // 네트워크 통신을 해서 json을 가지고 와 디코딩하고, 위에서 생성한 subject에 onNext해주는 함수
    func fetchRepositories(of organization: String) {
        Observable.from([organization]) // 함수에 넣을 "Apple"을 array 형태로 받을 from 사용
            .map { organization -> URL in
                return URL(string: "https://api.github.com/orgs/\(organization)/repos")! // URL 형태로 변환
            }
            .map { url -> URLRequest in
                var request = URLRequest(url: url) // URLRequest로 변환
                request.httpMethod = "GET"
                return request
            }
            .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
                return URLSession.shared.rx.response(request: request) // response를 rx로 변환
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
            .map { objects in
                return objects.compactMap { dic -> Repository? in // dictionary 형태를 repositoty 형태로 바꿈
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
}

// UITableView DataSourcr Delegate
extension RepositoryListViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        do {
            return try repositories.value().count
        } catch {
            return 0 // 에러가 발생해서 value 값을 뽑아낼 수 없는 경우
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "RepositoryListCell", for: indexPath) as? RepositoryListCell
            else { return UITableViewCell()}
        
        var currentRepo: Repository? {
            do {
                return try repositories.value()[indexPath.row]
            } catch {
                return nil
            }
        }
        
        cell.repository = currentRepo
        
        return cell
    }
}
