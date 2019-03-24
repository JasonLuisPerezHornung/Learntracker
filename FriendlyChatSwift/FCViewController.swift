

import UIKit
import Firebase
import FirebaseAuthUI
import FirebaseGoogleAuthUI
import Charts
// MARK: - FCViewControlle
struct SubjectsFields{
    var date_start: String
    var desc: String
    var duration: String
    var idsubject: String
    var long_desc: String
    var order: Int
    var task_desc: String
}
struct ActivitiesFields{
    var check_in: Date
    var check_out: Date
    var idstudent: String
    var idsubject: String
    var type: Int
}
struct EnrollmentsFields{
    var date: Date
    var idstudent: String
    var idsubject: String
}
struct StudentsFields{
    var active: Int
    var birth: Int
    var country: String
    var email: String
    var fullname: String
    var gender: String
    var idstudent: String
    var nick: String
    var type: Int
}

class FCViewController: UIViewController, UINavigationControllerDelegate {
    
    // MARK: Properties
    
    var ref: DatabaseReference!
    var db: Firestore!
    //var messages: [DataSnapshot]! = []
    var msglength: NSNumber = 1000
    var storageRef: StorageReference!
    var remoteConfig: RemoteConfig!
    let imageCache = NSCache<NSString, UIImage>()
    var keyboardOnScreen = false
    var placeholderImage = UIImage(named: "ic_account_circle")
    fileprivate var _refHandle: DatabaseHandle!
    fileprivate var _authHandle: AuthStateDidChangeListenerHandle!
    var user: User?
    var userEmail: String = ""
    var userId = "default"
    var displayName = "Anonymous"
    var chatroom = "room1"
    var activityGuard = false
    var enrolledGuard = false
    var timeStart: Date?
    var currentSubject: SubjectsFields?
    var subjects = [SubjectsFields]()
    var enrolledSubjects = [SubjectsFields]()
    var activities = [ActivitiesFields]()
    var data1 = PieChartDataEntry(value: 1)
    var data2 = PieChartDataEntry(value: 2)
    var array = [PieChartDataEntry]()
    
    // MARK: Outlets
    //Header
    @IBOutlet weak var usernameSettings: UILabel!
    @IBOutlet weak var SettingsBack: UIButton!
    //Header
    @IBOutlet weak var Settings: UIButton!
    //@IBOutlet weak var RoomsButton: UIButton!
    //
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var stopTimerButton: UIButton!
    
    //Sign in out
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!
    //SubjectDetails
    
    @IBOutlet weak var pieChart: PieChartView!
    
    @IBOutlet weak var messagesTable: UITableView!
    @IBOutlet weak var subjectNameDetail: UILabel!
    //Subjects List
    @IBOutlet weak var subjectsLabel: UILabel!
    @IBOutlet weak var subjectsTable: UITableView!
    @IBOutlet weak var backsubjectsView: UIButton!
    
    //Etc
    @IBOutlet weak var backgroundBlur: UIVisualEffectView!
    @IBOutlet weak var imageDisplay: UIImageView!
    @IBOutlet var dismissImageRecognizer: UITapGestureRecognizer!
    @IBOutlet var dismissKeyboardRecognizer: UITapGestureRecognizer!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        
        db = Firestore.firestore()
        configureAuth()
        self.subjectsTable.addSubview(self.refreshControl)
        let settings = db.settings
        settings.areTimestampsInSnapshotsEnabled = true
        db.settings = settings
        // old: let date: Date = documentSnapshot.get("created_at") as! Date
        // new:
        // let timestamp: Timestamp = documentSnapshot.get("created_at") as! Timestamp
        // let date: Date = timestamp.dateValue()
        
        //PIECHART
        
        
        //update data PIECHART
        updatePieChart()
        
    }
    func updatePieChart(){
        array = [data1,data2]
        let chartDataSet = PieChartDataSet(values: array, label: nil)
        let chartData = PieChartData(dataSet: chartDataSet)
        let colors = [UIColor.blue,UIColor.red]
        chartDataSet.colors = colors as! [NSUIColor]
        pieChart.data = chartData
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(FCViewController.handleRefresh(_:)), for: UIControlEvents.valueChanged)
        refreshControl.tintColor = UIColor.red
        
        return refreshControl
    }()
    
    func handleRefresh(_ refreshControl: UIRefreshControl) {
        self.loadEnrollments()
        refreshControl.endRefreshing()
    }
    
    // MARK: Config
    
    func configureAuth() {
        
        let provider: [FUIAuthProvider] = [FUIGoogleAuth()]
        FUIAuth.defaultAuthUI()?.providers = provider
        //listen changes
        _authHandle = Auth.auth().addStateDidChangeListener{(auth: Auth,user:User?)in
            //refresh table data
            //self.messages.removeAll(keepingCapacity: false)
            self.messagesTable.reloadData()
            self.subjectsTable.reloadData()
            // check if there is a current user
            if let activeUser = user {
                // check if the current app user is the current FIRUser
                if self.user != activeUser {
                    self.user = activeUser
                    self.signedInStatus(isSignedIn: true)
                    let name = user!.email!.components(separatedBy: "@")[0]
                    self.userEmail = user!.email!
                    self.usernameSettings.text = self.userEmail
                    self.displayName = name
                    self.getStudentId()
                    self.loadSubjects()
                }
            } else {
                // user must sign in
                self.signedInStatus(isSignedIn: false)
                self.loginSession()
            }
            
            
        }
    }
    /*
    func configureDatabase() {
        ref = Database.database().reference()
        
        _refHandle = ref.child(chatroom).observe(.childAdded) { (snapshot: DataSnapshot) in
            self.messages.append(snapshot)
            self.messagesTable.insertRows(at: [IndexPath(row: self.messages.count - 1, section: 0)], with: .automatic)
            
        }
        loadSubjects()
        
    } */
    
    func getStudentId(){
        
        db.collection("students").whereField("email", isEqualTo: userEmail).getDocuments()
        { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                if querySnapshot != nil {
                    for document in querySnapshot!.documents{
                        print("\(document.documentID) => \(document.get("idstudent")!)")
                        self.userId = document.get("idstudent") as? String ?? ""
                        self.loadEnrollments()
                        
                    }
                }else{
                  print("Error getting query")
                }
            }
        }
    }
    
    
    func loadEnrollments(){
        //whereField("idstudent", isEqualTo: userEmail).
        db.collection("enrollments").whereField("idstudent", isEqualTo: self.userId).getDocuments()
            { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    if querySnapshot != nil {
                        self.enrolledSubjects.removeAll()
                        
                        for document in querySnapshot!.documents{
                            
                            self.loadEnrolledSubjects(idsubject: document.get("idsubject") as? String ?? "")
                        }
                        self.enrolledGuard = true
                    }else{
                        print("Error getting query")
                    }
                }
        }
        
        
    }
    
    func loadEnrolledSubjects(idsubject : String){
        
        db.collection("subjects").whereField("idsubject", isEqualTo: idsubject).order(by: "order", descending: false).getDocuments() { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                if querySnapshot != nil {
                    
                    if(self.enrolledGuard){
                        self.enrolledSubjects.removeAll()
                        self.enrolledGuard = false
                    }
                    
                    for document in querySnapshot!.documents {
                        
                        print("\(document.documentID) => \(document.get("desc")!)")
                        
                        
                        let date_start = document.get("date_start") as? String ?? ""
                        let desc = document.get("desc") as? String ?? ""
                        let duration = document.get("duration") as? String ?? ""
                        let idsubject = document.get("idsubject") as? String ?? ""
                        let long_desc = document.get("long_desc") as? String ?? ""
                        let order = document.get("order") as? Int ?? 0
                        let task_desc = document.get("task_desc") as? String ?? ""
                        let subjSource = SubjectsFields(
                            date_start:date_start,
                            desc:desc,
                            duration:duration,
                            idsubject:idsubject,
                            long_desc:long_desc,
                            order:order,
                            task_desc:task_desc
                        )
                        
                        self.enrolledSubjects.append(subjSource)
                    }
                    self.subjectsTable.reloadData()
                }
            }
        }
    }
    
    func loadSubjects(){
        
        db.collection("subjects").order(by: "order", descending: false).addSnapshotListener() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                   if querySnapshot != nil {
                    
                    self.subjects.removeAll()
                    
                    for document in querySnapshot!.documents {
                        print("\(document.documentID) => \(document.get("desc")!)")
                        
                        
                        let date_start = document.get("date_start") as? String ?? ""
                        let desc = document.get("desc") as? String ?? ""
                        let duration = document.get("duration") as? String ?? ""
                        let idsubject = document.get("idsubject") as? String ?? ""
                        let long_desc = document.get("long_desc") as? String ?? ""
                        let order = document.get("order") as? Int ?? 0
                        let task_desc = document.get("task_desc") as? String ?? ""
                        let subjSource = SubjectsFields(
                            date_start:date_start,
                            desc:desc,
                            duration:duration,
                            idsubject:idsubject,
                            long_desc:long_desc,
                            order:order,
                            task_desc:task_desc
                        )
                        
                        self.subjects.append(subjSource)
                    }
                    self.subjectsTable.reloadData()
                  }
                }
        }
    }
    func loadActivities(subjectAct: String){
        
        db.collection("activities").whereField("idstudent", isEqualTo: self.userId).whereField("idsubject", isEqualTo: subjectAct).order(by: "check_out", descending: true).addSnapshotListener() { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                if querySnapshot != nil {
                    
                    self.activities.removeAll()
                    var activityTime = 0
                    for document in querySnapshot!.documents {
                        print("\(document.documentID) => \(document.get("idsubject")!)")
                        print("\(document.documentID) => \(document.get("check_in")!)")
                        print("\(document.documentID) => \(document.get("check_out")!)")
                        let check_in = document.get("check_in") as! Timestamp
                        let check_in_date = check_in.dateValue()
                        let check_out = document.get("check_out") as! Timestamp
                        let check_out_date = check_out.dateValue()
                        let idstudent = document.get("idstudent") as? String ?? ""
                        let idsubject = document.get("idsubject") as? String ?? ""
                        let type = document.get("type") as? Int ?? 0
                        let activitiesData = ActivitiesFields(
                            check_in:check_in_date,
                            check_out:check_out_date,
                            idstudent:idstudent,
                            idsubject:idsubject,
                            type:type
                        )
                        
                        let diffInSeconds = Calendar.current.dateComponents([.second], from: check_in_date, to: check_out_date).second!
                        activityTime = activityTime + diffInSeconds
                        self.activities.append(activitiesData)
                    }
                    self.messagesTable.reloadData()
                    self.data1 = PieChartDataEntry(value: Double(activityTime))
                    
                    self.data2.label = "Recomendada"
                    self.data1.label = "Tu avance"
                    self.updatePieChart()
                    
                    
                }
            }
        }
    }
    
    /*
    deinit {
        ref.child(chatroom).removeObserver(withHandle: _refHandle)
        Auth.auth().removeStateDidChangeListener(_authHandle)
    }
    */
    
    // MARK: Remote Config
    
    func configureRemoteConfig() {
        // create remote config setting to enable developer mode
        let remoteConfigSettings = RemoteConfigSettings(developerModeEnabled: true)
        remoteConfig = RemoteConfig.remoteConfig()
        remoteConfig.configSettings = remoteConfigSettings
    }
    
    func fetchConfig() {
        var expirationDuration: Double = 3600
        // if in developer mode, set cacheExpiration 0 so each fetch will retrieve values from the server
        if remoteConfig.configSettings.isDeveloperModeEnabled {
            expirationDuration = 0
        }
        
        // cacheExpirationSeconds is set to cacheExpiration to make fetching faser in developer mode
        remoteConfig.fetch(withExpirationDuration: expirationDuration) { (status, error) in
            if status == .success {
                print("Config fetched!")
                self.remoteConfig.activateFetched()
                let friendlyMsgLength = self.remoteConfig["friendly_msg_length"]
                if friendlyMsgLength.source != .static {
                    self.msglength = friendlyMsgLength.numberValue!
                    print("Friendly msg length config: \(self.msglength)")
                }
            } else {
                print("Config not fetched")
                print("Error \(String(describing: error))")
            }
        }
    }
    
    
    // MARK: Sign In and Out
    
    
    func signedInStatus(isSignedIn: Bool) {
        //RoomsButton.isHidden = !isSignedIn
        Settings.isHidden = !isSignedIn
        hideSettings(state: true)
        pieChart.isHidden = isSignedIn
        signInButton.isHidden = isSignedIn
        signOutButton.isHidden = !isSignedIn
        messagesTable.isHidden = isSignedIn
        subjectNameDetail.isHidden = isSignedIn
        backsubjectsView.isHidden = isSignedIn
        sendButton.isHidden = isSignedIn
        stopTimerButton.isHidden = isSignedIn
        subjectsTable.isHidden = !isSignedIn
        subjectsLabel.isHidden = !isSignedIn
        if (isSignedIn) {
            backgroundBlur.effect = nil
            
            // configureRemoteConfig()
            //fetchConfig()
        }
    }
    
    func loginSession() {
        let authViewController = FUIAuth.defaultAuthUI()!.authViewController()
        self.present(authViewController, animated: true, completion: nil)
        
    }
    
    
    // MARK: Send Message
    
    
    func sendMessage(data: [String:String]) {
        /*
        var mdata = data
        mdata[Constants.MessageFields.name] = displayName
        ref.child(chatroom).childByAutoId().setValue(mdata)
        */
    }
    
    
    // MARK: Alert
    
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let dismissAction = UIAlertAction(title: "Dismiss", style: .destructive, handler: nil)
            alert.addAction(dismissAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: Actions
    
    @IBAction func showLoginView(_ sender: AnyObject) {
        loginSession()
    }
    
    func hideInterface(state : Bool){
        messagesTable.isHidden = state
        sendButton.isHidden = state
    }
    
    func hideSettings(state : Bool){
        SettingsBack.isHidden = state
        usernameSettings.isHidden = state
    }
    
    func subjectSelected(subject : SubjectsFields){
        //enroll if not enrolled and show data + able to record
        hideSubjectView()
        currentSubject = subject
        data2 = PieChartDataEntry(value: Double(subject.duration)! )
        updatePieChart()
        subjectNameDetail.text = subject.desc + "\n " + subject.long_desc
        loadActivities(subjectAct: subject.idsubject)
        showSubjectDetail()
        
    }
    func hideSubjectView(){
        subjectsLabel.isHidden = true
        subjectsTable.isHidden = true
        
    }
    func showSubjectView(){
        self.loadEnrollments()
        subjectsLabel.isHidden = false
        subjectsTable.isHidden = false
        
    }
    func showSubjectDetail(){
        pieChart.isHidden = false
        messagesTable.isHidden = false
        backsubjectsView.isHidden = false
        subjectNameDetail.isHidden = false
        sendButton.isHidden = false
    }
    
    @IBAction func backSubjectDetail(_ sender: Any) {
        
        if(!activityGuard){
        pieChart.isHidden = true
        backsubjectsView.isHidden = true
        messagesTable.isHidden = true
        subjectNameDetail.isHidden = true
        sendButton.isHidden = true
        showSubjectView()
        }
    }
    
    @IBAction func settingsButton(_ sender: Any) {
        hideSubjectView()
        SettingsBack.isHidden = false
        usernameSettings.isHidden = false
    }
    
    @IBAction func exitSettings(_ sender: Any) {
        SettingsBack.isHidden = true
        usernameSettings.isHidden = true
        
        showSubjectView()
    }
    
    
    
    
    
    @IBAction func startActivity(_ sender: Any) {
        activityGuard = true
        sendButton.isEnabled = false
        stopTimerButton.isHidden = false
        timeStart = Date()
    }
    
    @IBAction func stopActivity(_ sender: Any) {
        var ref: DocumentReference? = nil
        ref = db.collection("activities").addDocument(data: [
            "check_in": timeStart!,
            "check_out": Date(),
            "idstudent": self.userId,
            "idsubject":currentSubject!.idsubject,
            "type": 0
            
        ]) { err in
            if let err = err {
                print("Error adding document: \(err)")
            } else {
                print("Document added with ID: \(ref!.documentID)")
            }
        }
        sendButton.isEnabled = true
        stopTimerButton.isHidden = true
        activityGuard = false
        
    }
    
    /*
    func disconnect(){
        
        ref.child(chatroom).removeObserver(withHandle: _refHandle)
        Auth.auth().removeStateDidChangeListener(_authHandle)
        
    }
    
    func reconnect(){
        self.messages.removeAll(keepingCapacity: false)
        self.messagesTable.reloadData()
        //configureDatabase()
        
    }
    */
    @IBAction func signOut(_ sender: UIButton) {
        do {
            try Auth.auth().signOut()
            hideSettings(state: true)
        } catch {
            print("unable to sign out: \(error)")
        }
    }
}

// MARK: - FCViewController: UITableViewDelegate, UITableViewDataSource

extension FCViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count:Int?
        
        if tableView == self.subjectsTable {
            count = enrolledSubjects.count
        }
        
        if tableView == self.messagesTable {
            count =  activities.count
        }
        
        return count!
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // dequeue cell
        if tableView == self.messagesTable{
            let cell = tableView.dequeueReusableCell(withIdentifier: "messageCell", for: indexPath)
            let source = activities[indexPath.row]
            cell.textLabel?.text = "\(source.idsubject)" + "\n " + " start:" + "\(source.check_in )" + "\n " + " final:" + "\(source.check_out )"
            return cell
            
        }
        if tableView == self.subjectsTable{
            let cell = tableView.dequeueReusableCell(withIdentifier: "subjectCell", for: indexPath)
            let source = enrolledSubjects[indexPath.row]
            cell.textLabel?.text = "\(source.idsubject)" + ": " + "\(source.desc)" + " " + "\(source.long_desc)"
            return cell
        }
        return UITableViewCell()
        
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if tableView == self.subjectsTable{
            print("You selected row at\(enrolledSubjects[indexPath.row])")
            self.subjectSelected(subject: enrolledSubjects[indexPath.row])
        }
        if tableView == self.messagesTable{
            print("You selected row at\(activities[indexPath.row])")
            
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
   
    
    
}

