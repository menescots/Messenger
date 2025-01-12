//
//  NewConversationViewController.swift
//  Messenger
//
//  Created by Agata Menes on 07/07/2022.
//

import UIKit
import JGProgressHUD

final class NewConversationViewController: UIViewController {

    public var completion: ((SearchResult) -> (Void))?
    
    private let spinner = JGProgressHUD(style: .dark)
    private var users = [[String: String]]()
    private var results = [SearchResult]()
    private var hasFetched = false
    
    private var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for Users..."
        return searchBar
    }()
    
    private let resultsTableView: UITableView = {
        let table = UITableView()
        table.register(SearchBarCustomCell.self,
                       forCellReuseIdentifier: SearchBarCustomCell.identifier)
        table.isHidden = true
        return table
    }()
    
    private let noResultLabel: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.text = "No Results"
        label.textAlignment = .center
        label.textColor = UIColor(named: "labelTextColor")
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(noResultLabel)
        view.addSubview(resultsTableView)
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
        
        searchBar.delegate = self
        view.backgroundColor = UIColor(named: "backgroundColor")

        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
        
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        resultsTableView.frame = view.bounds
        noResultLabel.frame = CGRect(x: 10,
                                     y: (view.height-100)/2,
                                     width: view.width-20,
                                     height: 100)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
}

extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
     func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
         let model = results[indexPath.row]
         let cell = tableView.dequeueReusableCell(withIdentifier: SearchBarCustomCell.identifier,
                                                  for: indexPath) as! SearchBarCustomCell
         cell.configure(with: model)
         return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        //start conversation
        let targetUserData = results[indexPath.row]
        
        dismiss(animated: true, completion: { [weak self] in
            
            self?.completion?(targetUserData)
            
        })
    }
}

extension NewConversationViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return
        }
        
        searchBar.resignFirstResponder()
        results.removeAll()
        spinner.show(in: view)
        
        searchUsers(query: text)
    }
    
    func searchUsers(query: String) {
        if hasFetched {
            //if it does: filter
            filterUsers(with: query)
        }
        else {
            //if not, fetch them
            DatabaseManager.shared.getAllUsers(completion: { [weak self] result in
                switch result {
                case .success(let userCollection):
                    self?.hasFetched = true
                    self?.users = userCollection
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print("Failed to fetch users \(error)")
                }
            })
        }
    }
    
    func filterUsers(with term: String) {
        //update ui
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
              hasFetched else {
            return
        }
        
        let currentUserSafeEmail = DatabaseManager.safeEmail(emailAdress: currentUserEmail)
        
        self.spinner.dismiss(animated: true)
        
        let results: [SearchResult] = users.filter({
            guard let email = $0["email"],
                  email != currentUserSafeEmail else {
                    return false
            }
            guard let name = $0["name"]?.lowercased() else {
                    return false
            }
            
            return name.hasPrefix(term.lowercased())
        }).compactMap({
            guard let email = $0["email"],
                  let name = $0["name"] else {
                    return nil
            }

            return SearchResult(name: name, email: email)
        })
        self.results = results
        
        updateUI()
    }
    
    func updateUI(){
        if results.isEmpty {
            noResultLabel.isHidden = false
            resultsTableView.isHidden = true
        } else {
            noResultLabel.isHidden = true
            resultsTableView.isHidden = false
            resultsTableView.reloadData()
        }
    }
    
}
